###
#
# Copyright (C) 2013 by Vaughn Iverson
# 
# cdbtiles
#
# With this you can use a CouchDB as a "tilelive.js" source or sink for 
# map tile / grid / tilejson data.
#
# See: https://github.com/mapbox/tilelive.js
#
# License:
#
# This project is free software released under the MIT/X11 license:
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
###

path = require 'path'
fs = require 'fs'
url = require 'url'
tilelive = require 'tilelive'
nano = require 'nano'

protocol = 'cdbtiles'

tile_name = (z, x, y) -> 
    if x? and y? and z?  
        { path : "tile_#{z}_#{x}_#{y}", name : 'tile' }
    else
        { path : 'tile_{z}_{x}_{y}', name : 'tile' }


grid_name = (z, x, y) -> 
    if x? and y? and z?  
        { path : "grid_#{z}_#{x}_#{y}", name : 'grid' }
    else
        { path : 'grid_{z}_{x}_{y}', name : 'grid' }

tilejson_name = "tilejson"

# Image type magic numbers snarfed from https://github.com/mapbox/node-tilejson 
get_mime_type = (bytes) ->
    if (bytes[0] is 0x89 and bytes[1] is 0x50 and bytes[2] is 0x4E and
        bytes[3] is 0x47 and bytes[4] is 0x0D and bytes[5] is 0x0A and
        bytes[6] is 0x1A and bytes[7] is 0x0A) 
            return 'image/png'
    else if (bytes[0] is 0xFF and bytes[1] is 0xD8 and
        bytes[bytes.length - 2] is 0xFF and bytes[bytes.length - 1] is 0xD9) 
            return 'image/jpeg'
    else if (bytes[0] is 0x47 and bytes[1] is 0x49 and bytes[2] is 0x46 and
        bytes[3] is 0x38 and (bytes[4] is 0x39 or bytes[4] is 0x37) and
        bytes[5] is 0x61) 
            return 'image/gif'
    else
        console.warn "tilecouch: Image data with unknown MIME type in putTile call to get_mime_type."
        return 'application/octet-stream'

class Tilecouch

    @registerProtocols = (tilelive) ->
        tilelive.protocols["#{protocol}:"] = @
    
    @list = (filepath, callback) ->
        callback new Error ".list not implemented for #{protocol}"

    @findID = (filepath, id, callback) ->
        callback new Error ".findID not implemented for #{protocol}"

    constructor : (uri, callback) ->
        @starts = 0
        tile_url = url.parse uri
        unless tile_url.protocol is "#{protocol}:"
            return callback new Error "Bad uri protocol '#{tile_url.protocol}'.  Must be #{protocol}."
        tilepath_match = tile_url.pathname.match new RegExp "(/[^/]+/)(#{tilejson_name})?"
        unless tilepath_match
            return callback new Error "Bad tile url path '#{tile_url.pathname}' for #{protocol}."
        tile_url.path = ''
        tile_url.pathname = ''
        tile_url.query = ''
        tile_url.search = ''
        tile_url.hash = ''
        tile_url.protocol = 'http:'
        @server = url.format tile_url
        @db = new nano(@server)
        tile_url.path = tilepath_match[1].toLowerCase()
        tile_url.pathname = tile_url.path
        @db_name = tile_url.path[1...-1]
        @source = url.format tile_url
        @couchdb = @db.use @db_name
        callback null, @

    close : (callback) ->
        callback null

    getInfo : (callback) ->
        @couchdb.get tilejson_name, {}, (err, info) =>  
            return callback err if err
            delete info._id
            delete info._rev
            callback null, info

    getTile : (z, x, y, callback, timeout = 500) ->
        tn = tile_name z, x, y
        @couchdb.attachment.get tn.path, tn.name, {}, (err, data) => 
            if err
                if err.status_code is 404
                    callback new Error('Tile does not exist')
                else if timeout <= 32000
                    setTimeout @getTile.bind(this), timeout, z, x, y, callback, timeout*2
                else
                    callback err    
            else
                callback null, data

    getGrid : (z, x, y, callback) ->
        gn = grid_name z, x, y
        @couchdb.attachment.get gn.path, gn.name, {}, (err, data) => 
            if err
                if err.status_code is 404
                    callback new Error('Grid does not exist')
                else if timeout <= 32000
                    setTimeout @getGrid.bind(this), timeout, z, x, y, callback, timeout*2
                else
                    callback err    
            else
                callback null, data

    startWriting : (callback) ->
        @starts += 1
        unless @starts is 1
            callback null
        else
            @db.db.list (err, dbs) =>
                return callback err if err
                unless @db_name in dbs
                    @db.db.create @db_name, (err) =>
                        return callback err if err
                        @couchdb = @db.use @db_name
                        callback null
                else
                    @db.db.destroy @db_name, (err) =>
                        return callback err if err
                        @db.db.create @db_name, (err) =>
                            return callback err if err
                            @couchdb = @db.use @db_name
                            callback null
        
    stopWriting : (callback) ->
        @starts -= 1
        callback null

    putInfo : (info, callback) ->
        unless @starts
            return callback new Error "Error, writing not started."
        tn = tile_name()    
        info.tiles = [ "#{@source}#{tn.path}/#{tn.name}" ]
        if info.grids?
            gn = grid_name()    
            info.grids = [ "#{@source}#{gn.path}/#{gn.name}" ]
        @couchdb.insert info, tilejson_name, callback 

    putTile : (z, x, y, tile, callback) ->
        unless @starts
            return callback new Error "Error, writing not started."
        tn = tile_name z, x, y 
        type = get_mime_type tile
        @couchdb.attachment.insert tn.path, tn.name, tile, type, {}, callback

    putGrid : (z, x, y, grid, callback) ->
        unless @starts
            return callback new Error "Error, writing not started."
        gn = grid_name z, x, y
        @couchdb.attachment.insert gn.path, gn.name, grid, 'application/json', {}, callback 

module.exports = Tilecouch

