#library(geojsonR)
#library(jsonlite)
library("rgdal")
library("dplyr")
setwd("../")
getwd()
setwd("./gtfs.1013.joshin_bus")
setwd("gtfs.2002.kusakaru")

#start of code

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

#merge ("trip_headsign" is a not essential field)
ikisaki <- trips %>% select(trip_id, trip_headsign)
stop_times <- stop_times %>% left_join(ikisaki, by="trip_id")


#timetable of each stops
timetb_stops <- as.character(unique(stop_times$stop_id))
stop_times_DAT <- NULL 
N <- length(timetb_stops)
for(i in 1:N){
  .stopId <- timetb_stops[i]
  .times_head  <- stop_times %>% filter(stop_id == .stopId) %>% select(departure_time, trip_headsign)
  .times_head  <- .times_head[order(as.POSIXct(.times_head$departure_time, format="%H:%M:%S")),]

#  .head  <- stop_times %>% filter(stop_id == .stopId) %>% select(trip_headsign)
  .times <- substr(as.character(.times_head[,1]), 1, 5) # [,1] =>  as vector
  .heads <- as.character(.times_head[,2]) 
   
  .times_paste <- NULL
  for(j in 1:length(.times)){
    .times_paste <- paste(.times_paste, .times[j], " (", .heads[j], ")", "\n", sep="")
  }
  
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

# end of code

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