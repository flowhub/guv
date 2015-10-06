
config = require './config'

updateRoleStats = (cfg, stats) ->
  if stats.average
    delete cfg.p if cfg.p
    cfg.process = stats.average
    delete cfg.stddev if cfg.stddev # no longer valid
  if stats.stddev
    cfg.stddev = stats.stddev

updateStats = (cfg, stats) ->
  for rolename, rolestats of stats
    roleconfig = cfg[rolename]
    continue if not roleconfig

    updateRoleStats roleconfig, rolestats
  return cfg

collectStdin = (callback) ->
  data = ""

  process.stdin.on 'data', (chunk) ->
    data += chunk.toString()
  process.stdin.on 'end', () ->
    return callback null, data

transformFile = (filepath, transformFunc, callback) ->
  fs = require 'fs'

  fs.readFile filepath, { encoding: 'utf-8' }, (err, contents) ->
    return callback err if err
    transformed = transformFunc contents
    fs.writeFile filepath, transformed, { encoding: 'utf-8', flag: 'w+' }, (err) ->
      return callback err

exports.main = main = () ->

  configfile = process.argv[2]
  throw new Error 'no config file specified' if not configfile

  collectStdin (err, data) ->
    stats = JSON.parse data
    transform = (contents) ->
      cfg = config.parseOnly contents
      cfg = updateStats cfg, stats
      return config.serialize cfg

    transformFile configfile, transform, (err) ->
      throw err if err
      console.log 'Updated', configfile

main() if not module.parent
