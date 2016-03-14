#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:newrelic')

try
  nr = require 'newrelic'
catch e
  debug 'Could not enable NewRelic: ', e

onError = (err) ->
  return if not nr

  nr.noticeError err

onStateChanged = (state) ->
  return if not nr

  for role, data of state
    event =
      role: role
      app: data.app
      jobs: data.current_jobs
      workers: data.new_workers
      drainrate: data.drainrate
      fillrate: data.fillrate
      consumers: data.consumers
    debug 'recording event', 'GuvScaled', role
    nr.recordCustomEvent 'GuvScaled', event

exports.register = (governor) ->
  debug 'register'
  governor.on 'state', onStateChanged
  governor.on 'error', onError

exports.unregister = (governor) ->
  debug 'unregister'
  governor.removeListener 'state', onStateChanged
  governor.removeListener 'error', onError
