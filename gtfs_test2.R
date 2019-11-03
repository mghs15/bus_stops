#library(geojsonR)
#library(jsonlite)
library("rgdal")
library("dplyr")
library("tidyr")
setwd("gtfs")
setwd("../")
getwd()
setwd("./gtfs.1013.joshin_bus")
setwd("gtfs.2002.kusakaru")
setwd("tokachibus")

#---------start of code---------

#####
#data import 
#####
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

  #出力形式の選択
  .is.table <- TRUE

  if(.is.table){

##########
  #時間部分
  .times_hr <- substr(.times_head$departure_time, 1, 2) 
  #構成要素 （時刻、行先、平日休日　等）をここで作ってしまう。
  .times_mm <- paste("<li>", substr(.times_head$departure_time, 4, 5), " (", .times_head$trip_headsign , ") ", .times_head$calendar_pattern, "</li>", sep="") 
  .time_head <- data.frame(hour=.times_hr, min_contents=.times_mm)
#  .time_head <- data.frame(hour=.times_hr, min_contents=.times_mm, trip_headsign=.times_head$trip_headsign)
#  .time_head <- .time_head %>% tidyr::spread(key = hour , value = min_contents)

  .unique_hours <- unique(.times_hr)
  .times_paste <- NULL
  for(k in 1:length(.unique_hours) ){
    .unique_hour <- .unique_hours[k]
    .unique_hour_subset <- subset(.time_head, hour == .unique_hour)
    .times_table_unique_paste <- paste(as.vector(.unique_hour_subset$min_contents), collapse = "")
    .times_paste <- paste(.times_paste, "<tr><td>", .unique_hours[k], "</td><td><ul>", .times_table_unique_paste, "</ul></td></tr>", sep="")
  }

  .times_paste <- paste("<table  border='1'>", .times_paste, "</table>", sep="") 
  
##########

  }else{　#出力形式の選択

##########
  #時間をPOSIXに直しておく。
  .times_head  <- .times_head[order(as.POSIXct(.times_head$departure_time, format="%H:%M:%S")),]  

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

#outpu as GeoJSON (use GDAL)
coordinates(stops.df.n) = c("stop_lon", "stop_lat")
stops.df.n@data <- stops.df.n@data %>% select("stop_name", "time_table")
colnames(stops.df.n@data) <- c("name", "時刻表") #　"時刻表n" -> "時刻表\n" REF) http://www.kent-web.com/pubc/garble.html

plot(stops.df.n)
class(stops.df.n)
writeOGR(stops.df.n, "stops.geojson", layer="layer", driver="GeoJSON", encoding="SJIS")

#---------end of code---------






############################################
## reserch:ENCODING
############################################
testdata <- stops.df.n@data
Encoding(testdata[,1])

#　"時刻表n" -> "時刻表\n" REF) http://www.kent-web.com/pubc/garble.html
# when read.csv(.... , stringsAsFactors = FALSE, encoding="UTF-8")
# and writeOGR(... , encoding="sjis"), things goes good.
# when read.csv(.... , stringsAsFactors = FALSE); (i.e. encoding is not set),
# and writeOGR(...); (i.e. encoding is not set), things not go good: Back slash "\" shown up after some Kanji.
# when read.csv(.... , stringsAsFactors = FALSE, encoding="UTF-8")
# and writeOGR(... , encoding="utf8"), ... terrible, Kanji goes <NA>.

#SJIS, NULL -> \
#SJIS,SJIS -> good! (Open UTF-8 in a text editior.=the output file is encoded as UTF-8)
#NULL,SJIS-> good! (Open UTF-8 in a text editior.=the output file is encoded as UTF-8)

############################################
## memo
############################################

stop_times.df <- stop_times %>% group_by(trip_id , stop_id)
stop_times_json <- toJSON(stop_times.df)

#stops.df <- stops %>% left_join() 

write(stop_times_json, "json_stptb.json")

coordinates(stops.df) = c("stop_lon", "stop_lat")
plot(stops.df)
class(stops.df)
writeOGR(stops.df, "stops.geojson", layer="layer", driver="GeoJSON")

str(stops.df)



#######
json.stop.pos <- cbind(stops[c("stop_lat", "stop_lon")])
plot(json.stop.pos)


json.stop <- toJSON(stops)
json.stops.latlng <- toJSON(json.stop.pos)

write(json.stop, "json_stp.json")

#######

coordinates(stops) = c("stop_lon", "stop_lat")
plot(stops)
class(stops)
writeOGR(stops, "stops.geojson", layer="layer", driver="GeoJSON")
