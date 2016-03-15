#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:heroku')
Heroku = require 'heroku-client'
child = require 'child_process'
async = require 'async'
statistics = require 'simple-statistics'

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


# input format:
# Scale to guv=1, measuremedia=1, solveslow=10, web=3 by team+gridbot@thegrid.io
parseScaleTo = (str) ->
  re = /Scale to (.*) by.*/
  match = re.exec str
  dynostr = match[1]
  dynos = {}
  for d in dynostr.split ', '
    [name, number] = d.split('=')
    dynos[name] = parseInt(number)
  return dynos

eventsFromLog = (logdata, started) ->
  events = []

  # TODO: allow to output a cleaned/minimized logfile. Especially for tests
  # timestamp, target (app|heroku), action
  re = /^(.*?) (\w+)\[(.*)\]: (.*)$/mg
  matches = matchAll re, logdata
  for m in matches
    [_full, timestamp, target, dyno, info] = m

    timestamp = new Date(timestamp)

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
    else if startsWith info, 'Scale to'
      # note: affects multiple dynos, each can go up, down or no change
      scaleTo = parseScaleTo info
      for name, number of scaleTo
        events.push { type: 'scale-to', time: timestamp, requested: number, dyno: name, msg: info }
    
    # Should we synthesize per-dyno events from it? requires context...

    else if startsWith info, 'State changed from up to down'
      events.push { type: 'up->down', time: timestamp, dyno: dyno, msg: info }
    else if startsWith info, 'State changed from starting to up'
      events.push { type: 'starting->up', time: timestamp, dyno: dyno, msg: info }

    else if startsWith info, 'Starting process with command'
      events.push { type: 'process-starting', time: timestamp, dyno: dyno, msg: info }
    else if started info
      events.push { type: 'process-started', time: timestamp, dyno: dyno, msg: info }

    else if startsWith info, 'Process exited with status'
      events.push { type: 'process-exited', time: timestamp, dyno: dyno, msg: info }
    else if startsWith info, 'Stopping all processes with SIGTERM'
      events.push { type: 'process-stopping', time: timestamp, dyno: dyno, msg: info }

    else
      #debug 'unknown-logline', info
  return events

# Basically a finite state machine, one per dyno
applyEvent = (state, event) ->
  # DynoState:    requested  |  starting   |  up  |   stopping  | (exited)
  state.lasttransition = {} if not state.lasttransition # 'dyno.N' -> lastTransition: Event }
  state.dynostate = {} if not state.dynostate # 'dyno.N' -> DynoState
  state.startups = [] if not state.startups
  state.shutdowns = [] if not state.shutdowns
  state.scaleups = [] if not state.scaleups
  state.requestedWorkers = {} if not state.requestedWorkers # 'dyno" -> Number

  # Note, they can happen initially because we don't generally know initial state
  if event.dyno
    # Dyno-specific events
    #console.log event.dyno, event.type
    switch event.type
      when 'scale-to'
        old = state.requestedWorkers[event.dyno]
        newValue = event.requested
        #console.log 'scale:', event.dyno, newValue, old, state.requestedWorkers
        if newValue > old
          # TODO: validate that number of running matches expected
          lastNotExited = 0
          for dynoname, dynostate of state.dynostate
            if startsWith dynoname, "#{event.dyno}."
              [dynorole, dynonr] = dynoname.split '.'
              dynonr = parseInt dynonr
              #console.log 's', dynoname, dynostate
              if dynostate != 'exited' and dynostate != 'requested' and dynonr > lastNotExited
                lastNotExited = dynonr
          firstNew = lastNotExited+1
          lastNew = firstNew+(newValue-old)-1
          for i in [firstNew..lastNew]
            name = "#{event.dyno}.#{i}"
            #console.log 'adding', name
            state.dynostate[name] = 'requested'
            state.lasttransition[name] = event
        else if newValue < old
          #console.log 'less', event.dyno, old, newValue
        else
          null # no change
        state.requestedWorkers[event.dyno] = newValue

      when 'process-starting'
        if state.lasttransition[event.dyno] and state.dynostate[event.dyno] == 'requested'
          s =
            dyno: event.dyno
            start: state.lasttransition[event.dyno]
            end: event
          s.duration = s.end.time.getTime() - s.start.time.getTime()
          state.scaleups.push s

          state.dynostate[event.dyno] = 'starting'
          state.lasttransition[event.dyno] = event
        else
          debug 'invalid transition', event.type, state.dynostate[event.dyno]
      when 'process-started'
        if state.lasttransition[event.dyno] and state.dynostate[event.dyno] == 'starting'
          s =
            dyno: event.dyno
            start: state.lasttransition[event.dyno]
            end: event
          s.duration = s.end.time.getTime() - s.start.time.getTime()
          state.startups.push s

          state.dynostate[event.dyno] = 'started'
          state.lasttransition[event.dyno] = event
        else
          debug 'invalid transition', event.type, state.dynostate[event.dyno]

      when 'starting->up' then null
      when 'up->down' then null

      when 'process-stopping'
        if state.dynostate[event.dyno] == 'started'
          state.dynostate[event.dyno] = 'stopping'
          state.lasttransition[event.dyno] = event
        else
          debug 'invalid transition', event.type, state.dynostate[event.dyno]

      when 'process-exited'
        if state.dynostate[event.dyno] == 'stopping' and state.lasttransition[event.dyno]
          s =
            dyno: event.dyno
            start: state.lasttransition[event.dyno]
            end: event
          s.duration = s.end.time.getTime() - s.start.time.getTime()
          state.shutdowns.push s

          state.dynostate[event.dyno] = 'exited'
          state.lasttransition[event.dyno] = event
        else
          debug 'invalid transition', event.type, state.dynostate[event.dyno]

  else
    # FIXME: handle. Maybe outside/before


analyzeStartups = (filename, started, callback) ->
  fs = require 'fs'

  state = {}
  fs.readFile filename, {encoding: 'utf-8'}, (err, contents) ->
    return callback err if err
    events = eventsFromLog contents, started
    #results = events.map (e) -> "#{e.dyno or ''} #{e.type}"
    for e in events
      applyEvent state, e

    starts = state.startups.map (s) -> s.duration/1000
    stops = state.shutdowns.map (s) -> s.duration/1000
    scaleups = state.scaleups.map (s) -> s.duration/1000
    results =
      scaleup: statistics.median scaleups
      scaleup_stddev: statistics.standard_deviation scaleups
      scaleup_length: scaleups.length
      startup: statistics.mean starts
      startup_stddev: statistics.standard_deviation starts
      startup_length: starts.length
      shutdown: statistics.mean stops
      shutdown_stddev: statistics.standard_deviation stops
      shutdown_length: stops.length
    return callback null, results

# TODO: calculate whole delay from scaling to up by default, and scaling down to down
# TODO: allow to separate between (module) loading time, and startup time
# TODO: add a guv-update-jobstats tool, would modify 'boot' and 'shutdown' values in config
# TODO: add tool for calculating scaling 'waste'. Ratio of time spent processing vs startup+shutdown
# MAYBE: allow specifying subsets in time?
# MAYBE: allow ignoring certain dynos?
exports.startuptime_main = () ->
  program = require 'commander'

  filename = null
  program
    .arguments('<heroku.log>')
    .option('--started <regexp>', 'Regular expression matching output sent by process when started',
            String, 'noflo-runtime-msgflo started')
    .action (f, env) ->
      filename = f
    .parse(process.argv)
  program.started = new RegExp program.started

  started = (info) ->
    return program.started.test info
  analyzeStartups filename, started, (err, res) ->
    throw err if err
    console.log res

