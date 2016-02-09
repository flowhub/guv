#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:heroku')
Heroku = require 'heroku-client'
child = require 'child_process'
async = require 'async'

exports.dryrun = false

exports.setWorkers = (config, workers, callback) ->
  options =
    token: process.env['HEROKU_API_KEY']
  heroku = new Heroku options

  # sort workers into belonging app/formation
  formations = {}
  for w in workers
    formations[w.app] = [] if not formations[w.app]
    formations[w.app].push { process: w.role, quantity: w.quantity }

  scaleFormation = (appname, cb) ->
    formation = formations[appname]
    heroku.apps(appname)
        .formation()
        .batchUpdate(updates: formation, cb)

  return callback null if exports.dryrun
  debug 'scaling', workers
  appnames = Object.keys formations
  async.map appnames, scaleFormation, (err, res) ->
    debug 'scaled returned', err, res
    return callback err, res


matchAll = (regexp, str) ->
  matches = []
  str.replace regexp, () ->
    arr = ([]).slice.call arguments, 0
    extras = arr.splice -2
    arr.index = extras[0]
    matches.push arr
  return matches

startsWith = (str, prefix) ->
  return str.indexOf(prefix) == 0


eventsFromLog = (logdata) ->
  events = []

  # timestamp, target (app|heroku), action
  re = /^(.*?) (\w+)\[(.*)\]: (.*)$/mg
  matches = matchAll re, logdata
  for m in matches
    [_full, timestamp, target, dyno, info] = m

    # known things to ignore
    if startsWith info, 'info'
    else if startsWith info, 'warn'
    else if startsWith info, 'err!'
      # debug messages
    else if startsWith info, 'at=info'
    else if startsWith info, 'sock=client'
      # Heroku router message
    else if startsWith info, 'Error:'
      # JS exception
    else if startsWith info, '{"v"'
      # NewRelic event thing
    else if startsWith info, 'source=HEROKU_POSTGRESQL'
      # NewRelic event thing

    # app specific. FIXME: make general
    else if startsWith info, 'Measurement task'
    else if startsWith info, 'New job'
    else if startsWith info, 'Received measurement'
    else if startsWith info, 'running: update'
    else if startsWith info, 'done'
    else if info.indexOf('noflo-runtime-msgflo:error') != -1

    # events we care about
    # FIXME: parse timestamps
    else if startsWith info, 'Scale to'
      events.push { type: 'scale-to', time: timestamp, msg: info }

    else if startsWith info, 'State changed from up to down'
      events.push { type: 'up->down', time: timestamp, dyno: dyno, msg: info }
    else if startsWith info, 'State changed from starting to up'
      events.push { type: 'starting->up', time: timestamp, dyno: dyno, msg: info }

    else if startsWith info, 'Starting process with command'
      events.push { type: 'process-starting', time: timestamp, dyno: dyno, msg: info }
    else if startsWith info, 'Process exited with status'
      events.push { type: 'process-exited', time: timestamp, dyno: dyno, msg: info }
    else if startsWith info, 'Stopping all processes with SIGTERM'
      events.push { type: 'process-stopping', time: timestamp, dyno: dyno, msg: info }
    else if startsWith info, 'noflo-runtime-msgflo started'
      events.push { type: 'process-started', time: timestamp, dyno: dyno, msg: info }
    else
      #console.log info
  return events

analyzeStartups = (filename, callback) ->
  fs = require 'fs'

  fs.readFile filename, {encoding: 'utf-8'}, (err, contents) ->
    return callback err if err
    events = eventsFromLog contents
    results = events.map (e) -> "#{e.dyno or ''} #{e.type}"
    return callback null, results

exports.startuptime_main = () ->
  program = require 'commander'

  filename = null

# TODO: allow specifying subsets in time?
  program
    .arguments('<heroku.log>')
#    .option('-f --file <FILE.guv>', 'Configuration file', String, '')
    .action (f, env) ->
      filename = f
    .parse(process.argv)

  analyzeStartups filename, (err, res) ->
    throw err if err
    console.log res

