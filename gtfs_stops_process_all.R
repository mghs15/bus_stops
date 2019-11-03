library("rgdal")
library("dplyr")
setwd("gtfs")


pathList <- list.files("set")

for(i in 1:length(pathList)){
  path <- paste("set/", pathList[i], sep="")
  setwd(path)
  make_busstop_geojson("../../data/", i)
  setwd("../")
  setwd("../")
}


########
agency_info_df <- read.table("data/agency_info.txt", header=FALSE)
D_layerinfo <- NULL
for(i in 1:nrow(agency_info_df)){
  aginfo <- agency_info_df[i,]
  title <- as.character(aginfo[1,1])
  lid <- strsplit(as.character(aginfo[1,3]), "\\.")[[1]][1]
  url <- paste("./data/", as.character(aginfo[1,3]), sep="")

  title <- paste('"title": "', title, '",', sep="")
  lid <- paste('"id": "', lid, '",', sep="")
  url <- paste('"url": "', url, '",', sep="")

  layerinfo <- paste('{"type": "Layer",', title, lid, url, '"cocotile": false,', '"html": "以下の著作物を利用。<br><a src=\'https://gma.jcld.jp/GMA_OPENDATA/\'>群馬県内バス路線情報（標準的なバス情報フォーマット）</a>、群馬県、<a href=\'http://creativecommons.org/licenses/by/4.0/deed.ja\'>クリエイティブ・コモンズ・ライセンス　表示4.0.国際（外部リンク）</a><br>実験的なものであり、正確性は保障できません。"},', sep="\n")
  D_layerinfo <- paste(D_layerinfo, layerinfo, sep="\n")
}
write.table(  D_layerinfo , "layers_busstop.txt", quote = FALSE, row.names=FALSE, col.names=FALSE)



############################################################################
#---------start of code---------

make_busstop_geojson = function(path = "", tag = ""){

############
#data import 
############
#agency
agency <- read.csv("agency.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
head(agency )
agency_name <- as.character(agency$agency_name[1])
agency_id <- as.character(agency$agency_id[1])

#stops
stops <- read.csv("stops.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
head(stops)
stops.df <- stops %>% filter(location_type == "0")

#stop_times
stop_times <- read.csv("stop_times.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(stop_times)

#trips
trips <- read.csv("trips.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(trips)

#calendar
calendar <- read.csv("calendar.txt", header = TRUE, fileEncoding = "utf8", stringsAsFactors = FALSE)
tail(calendar)

calendar_DAT <- NULL
for(i in 1:nrow(calendar)){
  calend <- calendar[i,]
  if(calend$monday == 1 & calend$tuesday == 1 & calend$wednesday == 1 & calend$thursday == 1 & calend$friday == 1 & calend$saturday == 1 & calend$sunday == 1 ){
    sche_day <- "全日"
  }else if(calend$monday == 1 & calend$tuesday == 1 & calend$wednesday == 1 & calend$thursday == 1 & calend$friday == 1 & calend$saturday == 0 & calend$sunday == 0 ){
    sche_day <- "<span style='color: #0000FF;'>平日のみ</span>"
  }else if(calend$monday == 0 & calend$tuesday == 0 & calend$wednesday == 0 & calend$thursday == 0 & calend$friday == 0 & calend$saturday == 1 & calend$sunday == 1){
    sche_day <- "<span style='color: #FF0000;'>休日のみ</span>"
  }else{
    sche_day <- ""
    if(calend$monday == 1){sche_day <- paste(sche_day, "月", sep="")}
    if(calend$tuesday == 1){sche_day <- paste(sche_day, "火", sep="")}
    if(calend$wednesday == 1){sche_day <- paste(sche_day, "水", sep="")}
    if(calend$thursday == 1){sche_day <- paste(sche_day, "木", sep="")}
    if(calend$friday == 1){sche_day <- paste(sche_day, "金", sep="")}
    if(calend$saturday == 1){sche_day <- paste(sche_day, "土", sep="")}
    if(calend$sunday == 1){sche_day <- paste(sche_day, "日", sep="")}
  }
  calendar_DAT <- c(calendar_DAT, sche_day)
}
calendar_shc <- calendar %>% select(service_id, start_date, end_date) %>% mutate(calendar_pattern = calendar_DAT)

#merge ("trip_headsign" is a not essential field)
trip_calendar <- trips %>% select(trip_id, trip_headsign, service_id)
trip_calendar <- trip_calendar %>% left_join(calendar_shc, by="service_id")
#ikisaki <- trips %>% select(trip_id, trip_headsign)
stop_times <- stop_times %>% left_join(trip_calendar, by="trip_id")
stop_times %>% head()

#時間のフィルタリング
ymd2time <- function(yyyymmdd){
  N <- length(yyyymmdd)
  TS <- NULL
  for(i in 1:N){
  str <- yyyymmdd[i]
    year_l <- substr(str, 1, 4)
    month_l <- substr(str, 5, 6)
    date_l <- substr(str, 7, 8)
    ymd <- paste(year_l, month_l, date_l, sep="-")
    TS <- c(TS, ymd)
  }
  return(TS)
}

stop_times$start_date  <- as.Date(ymd2time(stop_times$start_date) ) 
stop_times$end_date  <- as.Date(ymd2time(stop_times$end_date) )

today <- Sys.Date()

stop_times <- stop_times %>% filter(start_date < today | end_date > today)


########################
#timetable of each stops
########################
timetb_stops <- as.character(unique(stop_times$stop_id))
stop_times_DAT <- NULL 
N <- length(timetb_stops)
#for文内のみで利用する変数には、頭に「.」を付与
for(i in 1:N){
  .stopId <- timetb_stops[i]
  .times_head  <- stop_times %>% filter(stop_id == .stopId) %>% select(departure_time, trip_headsign, calendar_pattern)
  .times_head$calendar_pattern[is.na(.times_head$calendar_pattern)] <- "不明"
  .times_head  <- .times_head[order(as.POSIXct(.times_head$departure_time, format="%H:%M:%S")),]  

  #出力形式の選択
  .is.table <- TRUE

  if(.is.table){

##########
  #時間部分
  .times_hr <- substr(.times_head$departure_time, 1, 2) 
  #構成要素 （時刻、行先、平日休日　等）をここで作ってしまう。
  .times_mm <- paste("", substr(.times_head$departure_time, 4, 5), " (", .times_head$trip_headsign , ") ", .times_head$calendar_pattern, "", sep="") 
  .time_head <- data.frame(hour=.times_hr, min_contents=.times_mm)

#  .time_head <- data.frame(hour=.times_hr, min_contents=.times_mm, trip_headsign=.times_head$trip_headsign)
#  .time_head <- .time_head %>% tidyr::spread(key = hour , value = min_contents)

  .unique_hours <- unique(.times_hr)
  .times_paste <- NULL
  for(k in 1:length(.unique_hours) ){
    .unique_hour <- .unique_hours[k]
    .unique_hour_subset <- subset(.time_head, hour == .unique_hour)
    .times_table_unique_paste <- paste(as.vector(.unique_hour_subset$min_contents), collapse = "<br>")
    .times_paste <- paste(.times_paste, "<tr><td>", .unique_hours[k], "</td><td>", .times_table_unique_paste, "</td></tr>", sep="")
  }

  .times_paste <- paste("<table  border='1'>", .times_paste, "</table>", sep="") 
  
##########

  }else{　#出力形式の選択

##########

#構成要素 （時刻、行先、平日休日　等）
#  .head  <- stop_times %>% filter(stop_id == .stopId) %>% select(trip_headsign)
  .times <- substr(as.character(.times_head[,1]), 1, 5) # [,1] =>  as vector
  .heads <- as.character(.times_head[,2]) 
  .schedule <- as.character(.times_head[,3]) 

#ポップアップ文字列を作成。
  .times_paste <- NULL
  for(j in 1:length(.times)){
    .times_paste <- paste(.times_paste, "<li>", .times[j], " (", .heads[j], ") ",  .schedule[j], "</li>", sep="")
  }

  .times_paste <- paste("<ul>", .times_paste, "</ul>", sep="") 

##########  

  }#出力形式の選択を閉じる（.times_pasteに各行の出力を入れる。）


  .times_paste <- paste("<div style='max-height:150px;overflow:auto;'>", .times_paste, "</div>", sep="")
  .times <- c(.stopId, .times_paste)
  stop_times_DAT <- rbind(stop_times_DAT, .times)

}

colnames(stop_times_DAT) <- c("stop_id", "time_table")
rownames(stop_times_DAT) <- c(1:nrow(stop_times_DAT))
stop_times_DAT <- as.data.frame(stop_times_DAT, stringsAsfactors = FALSE)
stop_times_DAT$stop_id <- as.character(stop_times_DAT$stop_id)
stop_times_DAT$time_table <- as.character(stop_times_DAT$time_table)
head(stop_times_DAT$time_table)
head(stop_times_DAT)

#merge 
stops.df.n <- stops.df %>% select("stop_name", "stop_lat", "stop_lon", "stop_id") %>% left_join(stop_times_DAT, by="stop_id")

############
#data output 
############
#output as GeoJSON (use GDAL)
coordinates(stops.df.n) = c("stop_lon", "stop_lat")
stops.df.n@data <- stops.df.n@data %>% select("stop_name", "time_table")
stops.df.n@data <- stops.df.n@data %>% mutate( agency=rep(agency_name, nrow(stops.df.n@data)) )
stops.df.n@data <- stops.df.n@data %>% mutate( bikou=rep(paste(Sys.Date(), "時点の情報から作成"), nrow(stops.df.n@data)) )
colnames(stops.df.n@data) <- c("name", "時刻表", "運行", "備考")

plot(stops.df.n)
class(stops.df.n)
now_time <- Sys.time()
now_time <- gsub(":", "", now_time)
now_time <- gsub("-", "", now_time)
now_time <- gsub(" ", "", now_time)
now_time <- paste(now_time, tag, sep="")
output_tile_name <- paste(path, "stops_", agency_id, "_", as.character(now_time), ".geojson", sep="") 
writeOGR(stops.df.n, output_tile_name , layer="layer", driver="GeoJSON", encoding="SJIS")

#output agency information
agency_info <- paste(agency_name, agency_id, paste("stops_", agency_id, "_", as.character(now_time), ".geojson", sep=""), sep="\t")
write.table(agency_info, paste(path, "agency_info.txt", sep=""), quote = FALSE, row.names=FALSE, col.names=FALSE, append=TRUE, sep="\t")

} #全体をFunctionに。
#---------end of code---------