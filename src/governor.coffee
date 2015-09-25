#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:governor')
{ EventEmitter } = require 'events'

heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'

newState = (cfg, queues) ->
  state = {}
  for name, role of cfg
    continue if name == '*'
    state[name] = s = {}
    s.current_jobs = queues[role.queue]
    s.metric = role.metric
    s.app = role.app

    if not s.current_jobs?
      s.error = new Error "Could not get data for queue: #{role.queue}"
    else
      s.new_workers = scale.scale role, s.current_jobs

  return state

realizeState = (cfg, state, callback) ->
  workers = []
  for name, role of state
    continue if role.error
    workers.push
      app: role.app
      role: cfg[name].worker
      quantity: role.new_workers

  heroku.setWorkers cfg['*'], workers, (err) ->
    return callback err, state if err
    return callback null, state

checkAndScale = (cfg, callback) ->
  rabbitmq.getStats cfg['*'], (err, queues) ->
    return callback err if err

    state = newState cfg, queues
    realizeState cfg, state, callback

class Governor extends EventEmitter
  constructor: (c) ->
    @config = c
    @state =
      roles: {}
    for name, vars of @config
      continue if name == '*'
      @state.roles[name] = {}

    @interval = null

  # TODO: emit events on error, iteration
  start: () ->
    runFunc = () =>
      @runOnce (err, state) =>
        debug 'ran iteration', err, state
        @emit 'state', state
        @emit 'error', err if err
        for name, role of state
          @emit 'error', role.error if role.error

    interval = setInterval runFunc, 30*1000
    runFunc() # do first iteration right now

  stop: () ->
    clearInterval @interval if @interval

  runOnce: (callback) ->
    try
      checkAndScale @config, callback
    catch e
      return callback e

exports.Governor = Governor
