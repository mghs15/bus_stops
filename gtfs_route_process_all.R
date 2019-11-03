library("rgdal")
library("dplyr")
library(sp)
setwd("../")
getwd()
setwd("./gtfs.1013.joshin_bus")
setwd("gtfs.2002.kusakaru")
######################################
pathList <- list.files("set")

for(i in 1:length(pathList)){
  path <- paste("set/", pathList[i], sep="")
  setwd(path)
  make_busroute_geojson("../../data/", i)
  setwd("../")
  setwd("../")
}

########
agency_info_df <- read.table("data/agency_info_busroute.txt", header=FALSE)
D_layerinfo <- NULL
for(i in 1:nrow(agency_info_df)){
  aginfo <- agency_info_df[i,]
  title <- as.character(aginfo[1,1])
  lid <- strsplit(as.character(aginfo[1,3]), "\\.")[[1]][1]
  url <- paste("./data/", as.character(aginfo[1,3]), sep="")

  title <- paste('"title": "', title, '",', sep="")
  lid <- paste('"id": "', lid, '",', sep="")
  url <- paste('"url": "', url, '",', sep="")

  layerinfo <- paste('{"type": "Layer",', title, lid, url, '"cocotile": false,', '"html": "�����I�Ȃ��̂ł���A���m���͕ۏ�ł��܂���B<br>�ȉ��̒��앨�𗘗p�B<br><a href=\'https://gma.jcld.jp/GMA_OPENDATA/\' target=\'_blank\'>�Q�n�����o�X�H�����i�W���I�ȃo�X���t�H�[�}�b�g�j</a>�A�Q�n���A<a href=\'http://creativecommons.org/licenses/by/4.0/deed.ja\' target=\'_blank\'>�N���G�C�e�B�u�E�R�����Y�E���C�Z���X�@�\��4.0.���ہi�O�������N�j</a>"},', sep="\n")
  D_layerinfo <- paste(D_layerinfo, layerinfo, sep="\n")
}
write.table(  D_layerinfo , "layers_busroute.txt", quote = FALSE, row.names=FALSE, col.names=FALSE)



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
route_spdat <- route_spdat %>%  select("route_id", "trip_id", "service_id", "stop_id", "arrival_time", "stop_name", "stop_lat", "stop_lon")
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
#�`�F�b�N
#LDAT
#str(LDAT)


#sp line
proj <- CRS("+proj=longlat +datum=WGS84")
splinelist <- vector("list", length = length(route_identifier))
DF_list <- vector("list", length = length(route_identifier))
V_stops_paste <- NULL

for(i in 1:length(route_identifier)){
  .route <- route_identifier[i]
  .rout_sp_data <- LDAT[[.route]][[1]] # �ŏ���1�������p
  .rout_sp_data <- .rout_sp_data[order(as.POSIXct(.rout_sp_data$arrival_time, format="%H:%M:%S")),] 
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

#�`�F�b�N
#str(splinelist)

sp_lines <- SpatialLines(splinelist, proj4string=proj)

#�f�[�^�t���[��
out_agency_name <- rep( agency_name, length(route_identifier) )
out_agency_id <- rep( agency_id, length(route_identifier) )

#SpatialLinesDataFrame
lineColors <- rainbow(length(route_identifier)) 
out_data <- data.frame(operate=out_agency_name, busRoute=V_stops_paste, lineColor=lineColors, row.names = route_identifier)
colnames(out_data) <- c("�^�s", "�o�H", "_color")
sp_line_df <- SpatialLinesDataFrame(sp_lines, data=out_data)


#geojson�ŏo��
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


}#function�����B


