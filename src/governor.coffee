#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:governor')
{ EventEmitter } = require 'events'

heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'

# NOTE: original order
extractHistory = (history, rolename, key) ->
  predictions = []
  for state in history
    predictions.push state[rolename][key]
  return predictions

nextState = (cfg, window, queues) ->

  state = {}
  # TODO: store timestamps?
  for name, role of cfg
    continue if name == '*'
    state[name] = s = {}
    s.current_jobs = queues[role.queue]
    s.metric = role.metric
    s.app = role.app

    if not s.current_jobs?
      s.error = new Error "Could not get data for queue: #{role.queue}"
    else
      history = extractHistory window, name, 'estimated_workers'
      currentWorkers = extractHistory(window, name, 'current_workers')[history.length-1]
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

checkAndScale = (cfg, history, callback) ->
  rabbitmq.getStats cfg['*'], (err, queues) ->
    return callback err if err

    state = nextState cfg, history, queues
    realizeState cfg, state, callback

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


    interval = setInterval runFunc, @pollinterval
    runFunc() # do first iteration right now

  stop: () ->
    clearInterval @interval if @interval

  runOnceInternal: (callback) ->
    try
      checkAndScale @config, @history, (err, state) =>
        @history.push state
        @history = @history.slice Math.max(@history.length-@historysize, 0)
        debug 'history length', @history.length
        return callback err, state
    catch e
      return callback e

  runOnce: (callback) ->
    @runOnceInternal (err, state) =>
      debug 'ran iteration', err, state
      @emit 'state', state
      @emit 'error', err if err
      for name, role of state
        @emit 'error', role.error if role.error
      return callback err, state

exports.Governor = Governor
