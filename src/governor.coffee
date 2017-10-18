#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:governor')
{ EventEmitter } = require 'events'
bluebird = require 'bluebird'

heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'

# NOTE: original order
extractHistory = (history, rolename, key) ->
  predictions = []
  for state in history
    predictions.push state[rolename][key]
  return predictions

locateConfigEntry = (cfg, appName, processName) ->
  for name, value of cfg
    return name if (appName == value.app && processName == (value.worker || name))

nextState = (cfg, window, queues, queueDetails, currentWorkers) ->

  workersObject = {}

  for w in currentWorkers
    # Here w.role is the heroku process name. We need to map
    # based on app, process name to the key in the config (as they are
    # not necessarily one and the same.)
    configKey = locateConfigEntry(cfg, w.app, w.role)
    workersObject[configKey] = w

  state = {}
  # TODO: store timestamps?
  for name, role of cfg
    continue if name == '*'
    state[name] = s = {}
    s.current_jobs = queues[role.queue]
    s.metric = role.metric
    s.app = role.app
    details = queueDetails[role.queue]
    if details?
      s.consumers = details.consumers
      s.drainrate = details.drainrate
      s.fillrate = details.fillrate

    if not s.current_jobs?
      s.error = new Error "Could not get data for queue: #{role.queue}"
    else
      history = extractHistory window, name, 'estimated_workers'
      currentWorkers =  # Heroku
      s.previous_workers = workersObject[name].quantity
      workers = scale.scaleWithHistory role, name, history, currentWorkers, s.current_jobs
      s.estimated_workers = workers.estimate
      if workers.next?
        s.new_workers = workers.next
        s.current_workers = workers.next
      else
        # remember for later
        s.current_workers = currentWorkers

  return state

realizeState = (cfg, state, callback) ->
  workers = []
  for name, role of state
    continue if role.error
    continue if not role.new_workers?
    workers.push
      app: role.app
      role: cfg[name].worker
      quantity: role.new_workers

  heroku.setWorkers cfg['*'], workers, (err) ->
    return callback err, state if err
    return callback null, state

# polyfill for Object.values...
objectValues = (obj) ->
  vals = []
  for key, val of obj
    vals.push val
  return vals

historyStateValid = (s) ->
  return s.error or s.estimated_workers?
historyEntryValid = (r) ->
  return objectValues(r).every historyStateValid
historyValid = (h) ->
  checks =
    isArray: Array.isArray h
    entries: if h.length then h.every (e) -> historyEntryValid e else true
  return objectValues(checks).every (p) -> p == true

# Throws Error if not valid
exports.validateHistory = validateHistory = (h) ->
  throw new Error "Invalid history object: #{JSON.stringify(h)}" if not historyValid h

class Governor extends EventEmitter
  constructor: (c) ->
    @config = c
    @history = []
    @interval = null

    @historysize = Math.floor(@config['*'].history/@config['*'].pollinterval)
    @pollinterval = @config['*'].pollinterval*1000

  start: () ->
    runFunc = () =>
      @runOnce (err, state) =>
        # error and state are emitted,

    interval = setInterval runFunc, @pollinterval
    runFunc() # do first iteration right now

  stop: () ->
    clearInterval @interval if @interval

  updateHistory: (history) ->
    validateHistory history
    @history = history
    @history = @history.slice Math.max(@history.length-@historysize, 0)
    debug 'history length', @history.length

  nextState: (queues, details, workers) ->
    state = nextState @config, @history, queues, details, workers
    history = @history.concat [ state ]
    @updateHistory history
    return state

  runOnceInternal: (callback) ->
    getQueues = (mainConfig) ->
      bluebird.promisify(rabbitmq.getStats, multiArgs: true)(mainConfig)
      .then (results) ->
        r =
          queues: results[0]
          details: results[1]
        return Promise.resolve r

    getWorkers = bluebird.promisify heroku.getWorkers

    bluebird.props(
      rabbitmq: getQueues @config['*']
      workers: getWorkers @config
    ).then (current) =>
      state = @nextState current.rabbitmq.queues, current.rabbitmq.details, current.workers
      return bluebird.promisify(realizeState)(@config, state)
    .asCallback callback
    return null

  runOnce: (callback) ->
    @runOnceInternal (err, state) =>
      debug 'ran iteration', err, state
      @emit 'error', err if err
      for name, role of state
        @emit 'error', role.error if role.error
      @emit 'state', state
      return callback err, state

exports.Governor = Governor
