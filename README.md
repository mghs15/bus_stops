# bus_stops
「標準的なバス情報フォーマット」（GTFS-JP） を使ってみる



## バス停ごとの時刻表を作成

###サンプルデータ
[こちらの地図](https://mghs15.github.io/bus_stops/map/#13/36.340249/139.033458/&base=pale&ls=pale%7Cstops_5070001007099_201911031905116&disp=11&lcd=stops_5070001007099_201911031905116&vs=c1j0h0k0l0u0t0z0r0s0m0f1&d=vl)でご覧いただけます。

###スクリプト
```gtfs_test.R```

とりあえず、以下のデータを変換して地図上に表示できるようにした。
[群馬県内バス路線情報（標準的なバス情報フォーマット）](https://gma.jcld.jp/GMA_OPENDATA/)
のうち、「上信電鉄」と「草軽交通」のデータを利用。

結果は`stops_points`以下に格納した。

GTFSの一連のファイルのうち、

* stops.txt
* stop_times.txt
* trips.txt

を利用。

バス停のID(stop_id)に紐付けられた時刻表データ(ここでは、departure_time)を取得。
また、時刻表データのtrip_idに紐づけられた行先(trip_headsign)を取得。
最後に、GeoJSONとして出力する（[地理院地図](https://maps.gsi.go.jp/)にとりあえず取り込んである程度きれいに表示されることを目標にした）。

※行先(trip_headsign)はGTFSの必須データではないので注意。

```gtfs_test.R```

曜日も追加できるように修正　

### memo
エンコードの処理が大変だった。「表」がなぜか「表\」と出力されてしまう（原因は、[こういうこと](http://www.kent-web.com/pubc/garble.html)らしい。）。
GeoJSONとして出力する際に、
`writeOGR(... , driver="GeoJSON", encoding="SJIS")`
のように、Shift-JISを設定して上げるとうまくいったみたい。テキストエディタで確認すると、UTF-8で問題なく出力されている。


## 経路のラインデータを作成
```gtfs_test2.R```

経路のラインデータはshapes.txtに入っているらしいのだが、必須項目ではない。そのため、shapes.txtが整備されていないこともあるので、その場合、route_idごとに経由するバス停（stop_id）の経緯度をつないでラインデータとした。
例として、[群馬県内バス路線情報（標準的なバス情報フォーマット）](https://gma.jcld.jp/GMA_OPENDATA/)のうち、「上信電鉄」と「草軽交通」のデータを利用。

結果は`route_line`以下に格納した。

経緯度を持つバス停のデータとルートID（route_id）を結び付けるには、まず、バス停のID(stop_id)が属する便のID(trip_id)に結び付け、trip_idを使ってroute_idに結びつける必要がある。ライブラリdplyrを使って、データベースのごとくroute.txt、trips.txt、stop.txt、stops.txtをjoinしてしまえばよい。また、発車時刻（arrival_time）を使って経由するバス停を並び替えた。あるひとつのルートを経由する便は1つ以上あるが、どれでも同じと考え、ひとつだけ取り出してラインデータを作成した。






