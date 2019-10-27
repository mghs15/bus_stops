# bus_stops
「標準的なバス情報フォーマット」（GTFS-JP） を使ってみる



## バス停ごとの時刻表を作成
`gtfs_test.R`
とりあえず、以下のデータを変換。
[群馬県内バス路線情報（標準的なバス情報フォーマット）](https://gma.jcld.jp/GMA_OPENDATA/)
のうち、「上信電鉄」と「草軽交通」のデータを利用。

結果は以下のファイル
`stop.2002.kusakaru.geojson`
`stops.1013.joshin_bus.geojson`

GTFSの一連のファイルのうち、
* stops.txt
* stop_times.txt
* trips.txt
を利用。

バス停のID(stop_id)に紐付けられた時刻表データ(ここでは、arrival_time)を取得。
また、時刻表データのstop_idに紐づけられた行先(trip_headsign)を取得。
最後に、GeoJSONとして出力する（[地理院地図](https://maps.gsi.go.jp/)にとりあえず取り込んである程度きれいに表示されることを目標にした）。

※行先(trip_headsign)はGTFSの必須データではないので注意。

今回の試作では、曜日の区別はしていないが、実用化するには必須だろう。




