
'2017-03-01'

fs = require 'fs'
{ spawn } = require 'child_process'

haveData = (file, callback) ->
  fs.exists file, (exists) ->
    return callback null, false if not exists
    fs.stat file, (err, stat) ->
      return callback err if err
      hasData = stat.size > 1
      return callback null, hasData 

main = () ->
  haveData 'the-grid-api-march18.json', (err, data) ->
    console.log 'err', err, data

main() if not module.parent 
