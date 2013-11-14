cdbtiles 
==============================

cdbtiles is a [tilelive.js](https://github.com/mapbox/tilelive.js) backend (source/sink) plug-in for [CouchDB](https://couchdb.apache.org/) 

Q: What the heck does that mean?  

A: With this installed, you can use CouchDB to read/write map image tiles from other tilelive.js sources/sinks (mbtiles, Mapnik, TileJSON, S3, etc.)

Q: Come again?

A: You can use CouchDB to serve maps over HTTP.

Q: Why would you want to do that?

A: For the same reasons you might want to do anything else with CouchDB... As one example, you could write a self-contained [CouchApp](http://www.couchapp.org/page/what-is-couchapp) with mapping functionality.

Q: Where do the maps come from?

A: That's a really big question.  Weeks are probably required to fully grok what you are asking here.  

Places to start:  

+ [OpenStreetMap](http://www.openstreetmap.org)
+ [TileMill](https://www.mapbox.com/tilemill/)

#### Installation 

You need [node.js](http://nodejs.org/).  Then:
     
     npm install cdbtiles

Nice!  Now what?

#### Usage

Obviously, this works with (and depends upon) tilelive.js and CouchDB.

For example: Let's say you already have map tiles rendered with TileMill sitting in a .mbtiles file, and using something like [TileStream](https://github.com/mapbox/tilestream) to serve tiles alongside an application server isn't doing it for you. And you also happen to have a CouchDB server running locally.

You should be able to easily copy all of your data from the .mbtiles file to your local CouchDB (and then replicate it on from there) by setting up these other things:
     
     npm install tilelive
     npm install mbtiles

And then:

     ./node_modules/tilelive/bin/copy -s pyramid --minzoom=10 --maxzoom=18  "mbtiles:///Users/user/maps/Columbus.mbtiles" "cdbtiles://127.0.0.1:5984/columbus_tiles/"

The `copy` command above is a sample application provided by tilelive.js, and it has a bunch more options that you should check out. Tilelive is actually an API that any other app can use, so cdbtiles should enable CouchDB to play nicely with apps and other data sources/sinks that also support tilelive. The source and sink URIs have custom protocols (mbtiles: and cdbtiles:) that tilelive knows what to do with via the backend plugins you've now installed.  

Now, if you point a [Leaflet](http://leafletjs.com/) enabled web page page to `http://127.0.0.1:5984/columbus_tiles/tile_{z}_{x}_{y}/tile` you'll be serving up map tiles from CouchDB.  Put that webpage in your CouchDB as well (left as an excercise for the reader), and you now have a self-contained map/application server running on CouchDB. 

For what its worth, this also lets you to serve up the [TileJSON](https://github.com/mapbox/tilejson-spec) information for your maps, just use: `http://127.0.0.1:5984/columbus_tiles/tilejson`


