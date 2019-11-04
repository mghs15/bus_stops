library("rgdal")
library("dplyr")
library(sp)
setwd("gtfs/")
setwd("set/")
setwd("../")
getwd()
setwd("./gtfs.1013.joshin_bus")
setwd("gtfs.2002.kusakaru")
######################################
pathList <- list.files("set")

for(i in 1:length(pathList)){
  path <- paste("set/", pathList[i], sep="")
  setwd(path)
  make_busroute_geojson("../../data/route/", i)
  setwd("../")
  setwd("../")
}

########
agency_info_df <- read.table("data/route/agency_info_busroute.txt", header=FALSE)
D_layerinfo <- NULL
for(i in 1:nrow(agency_info_df)){
  aginfo <- agency_info_df[i,]
  title <- as.character(aginfo[1,1])
  lid <- strsplit(as.character(aginfo[1,3]), "\\.")[[1]][1]
  url <- paste("./data/route/", as.character(aginfo[1,3]), sep="")

  title <- paste('"title": "', title, '",', sep="")
  lid <- paste('"id": "', lid, '",', sep="")
  url <- paste('"url": "', url, '",', sep="")

  layerinfo <- paste('{"type": "Layer",', title, lid, url, '"cocotile": false,', '"html": "実験的なものであり、正確性は保障できません。<br>以下の著作物を利用。<br><a href=\'https://gma.jcld.jp/GMA_OPENDATA/\' target=\'_blank\'>群馬県内バス路線情報（標準的なバス情報フォーマット）</a>、群馬県、<a href=\'http://creativecommons.org/licenses/by/4.0/deed.ja\' target=\'_blank\'>クリエイティブ・コモンズ・ライセンス　表示4.0.国際（外部リンク）</a>"},', sep="\n")
  D_layerinfo <- paste(D_layerinfo, layerinfo, sep="\n")
}
write.table(  D_layerinfo , "layers_busroute.txt", quote = FALSE, row.names=FALSE, col.names=FALSE)

#改行の処理、文字コード、最後のコンマは手動で処理

######################################
make_busroute_geojson = function(path = "", tag = ""){

#agency
agency <- read.csv("agency.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
head(agency )
agency_name <- as.character(agency$agency_name[1])
agency_id <- as.character(agency$agency_id[1])

#stops
stops <- read.csv("stops.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
head(stops)

#stop_times
stop_times <- read.csv("stop_times.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(stop_times)

#trips
trips <- read.csv("trips.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(trips)

#routes
routes <- read.csv("routes.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(routes)

#calendar
calendar <- read.csv("calendar.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(calendar)


#####
#JOIN
#####
route_spdat <- stops %>%  left_join(stop_times, by = "stop_id")  %>% left_join(trips, by = "trip_id")  %>% left_join(routes, by = "route_id") 
route_spdat <- route_spdat %>%  select("route_id", "trip_id", "service_id", "stop_id", "stop_sequence", "arrival_time", "stop_name", "stop_lat", "stop_lon")
route_spdat <- na.omit(route_spdat)
route_spdat <- route_spdat[order(route_spdat$route_id), ]
route_spdat <- route_spdat[order(route_spdat$trip_id), ] 

#to List
route_identifier <- as.character(unique(route_spdat$route_id))
LDAT  <- vector("list", length = length(route_identifier))
for(i in 1:length(route_identifier)){
  .route <- route_identifier[i]
  .route_df <- route_spdat %>% filter(route_id == .route )
  .trip_identifier <- as.character(unique(.route_df$trip_id))
  .LDAT_trip <- vector("list", length = length(.trip_identifier))
  for(j in 1:length(.trip_identifier)){
    .trip <- .trip_identifier[j]
    .trip_df <- .route_df %>% filter(trip_id == .trip )
    .LDAT_trip[j] <- list(.trip_df)
    names(.LDAT_trip)[j] <- .trip
  }
  LDAT[i] <- list(.LDAT_trip)
  names(LDAT)[i] <- .route  
}
#チェック
#LDAT
#str(LDAT)


#sp line
proj <- CRS("+proj=longlat +datum=WGS84")
splinelist <- vector("list", length = length(route_identifier))
DF_list <- vector("list", length = length(route_identifier))
V_stops_paste <- NULL

for(i in 1:length(route_identifier)){
  .route <- route_identifier[i]
  .rout_sp_data <- LDAT[[.route]][[1]] # 最初の1つだけ利用
  .rout_sp_data <- .rout_sp_data[order(.rout_sp_data$stop_sequence),] 
  .stops_paste <- ""
  for(j in 1:length(.rout_sp_data$stop_name)){
    .stops_paste <- paste(.stops_paste, "<tr><td>", .rout_sp_data$stop_name[j], "</td></tr>", sep="")
  }
  .stops_paste <- paste("<div style='max-height:150px;overflow:auto;'><table>", .stops_paste, "</table></div>", sep="")
  V_stops_paste <- c(V_stops_paste, .stops_paste)
  
  .line <- Line(cbind(.rout_sp_data$stop_lon, .rout_sp_data$stop_lat))
  .lines <- Lines(list(.line), ID=.route)
  splinelist[i] <- list(.lines)
}

#チェック
#str(splinelist)

sp_lines <- SpatialLines(splinelist, proj4string=proj)

#データフレーム
out_agency_name <- rep( agency_name, length(route_identifier) )
out_agency_id <- rep( agency_id, length(route_identifier) )

#SpatialLinesDataFrame
lineColors <- rainbow(length(route_identifier)) 
out_data <- data.frame(operate=out_agency_name, busRoute=V_stops_paste, lineColor=lineColors, row.names = route_identifier)
colnames(out_data) <- c("運行", "経路", "_color")
sp_line_df <- SpatialLinesDataFrame(sp_lines, data=out_data)


#geojsonで出力
now_time <- Sys.time()
now_time <- gsub(":", "", now_time)
now_time <- gsub("-", "", now_time)
now_time <- gsub(" ", "", now_time)
now_time <- paste(now_time, tag, sep="")
outputname <- paste(path, "busroute_", agency_id, "_", as.character(now_time), ".geojson", sep="") 
writeOGR(sp_line_df, outputname, layer="route", driver="GeoJSON", encoding="SJIS")

plot(sp_line_df)

#output agency information
agency_info <- paste(agency_name, agency_id, paste("busroute_", agency_id, "_", as.character(now_time), ".geojson", sep=""), sep="\t")
write.table(agency_info, paste(path, "agency_info_busroute.txt", sep=""), quote = FALSE, row.names=FALSE, col.names=FALSE, append=TRUE, sep="\t")


}#functionを閉じる。



