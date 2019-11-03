library("rgdal")
library("dplyr")
library(sp)
setwd("../")
getwd()
setwd("./gtfs.1013.joshin_bus")
setwd("gtfs.2002.kusakaru")
######################################

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
LDAT


proj <- CRS("+proj=longlat +datum=WGS84")
for(i in 1:length(route_identifier)){
  .route <- route_identifier[i]
  .outputname <- paste("route_", .route, ".geojson", sep="")
  .rout_sp_data <- LDAT[[.route]][[1]]
  .rout_sp_data <- .rout_sp_data[order(as.POSIXct(.rout_sp_data$arrival_time, format="%H:%M:%S")),] 

  .line <- Line(cbind(.rout_sp_data$stop_lon, .rout_sp_data$stop_lat))
  .lines <- Lines(list(.line), ID=.route)
  .sp_lines <- SpatialLines(list(.lines), proj4string=proj)
  
  .stops_paste <- "[経路]"
  for(j in 1:length(.rout_sp_data$stop_name)){
    .stops_paste <- paste(.stops_paste, "\n", .rout_sp_data$stop_name[j], sep="")
  }
  .stops_paste <- paste("<div style='max-height:150px;overflow:auto;'>", .stops_paste, "</div>", sep="")
  
  .out_data <- matrix(c(.route, .stops_paste), ncol=2)
  .out_data <- as.data.frame(.out_data)
  rownames(.out_data) <- .route
  colnames(.out_data) <- c("ROUTE_NAME", "STOPS")
  .sp_line_df <- SpatialLinesDataFrame(.sp_lines, data=.out_data)
  writeOGR(.sp_line_df, .outputname, layer="route", driver="GeoJSON", encoding="SJIS")
}

################

head(route_spdat, n=20)
write.csv(route_spdat, "_test.route.csv")
