
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
      app: data.app
      jobs: data.current_jobs
      workers: data.new_workers
      role: role
    debug 'recording event', 'GuvScaled'
    nr.recordCustomEvent 'GuvScaled', event

exports.register = (governor) ->
  debug 'register'
  governor.on 'state', onStateChanged
  governor.on 'error', onError

exports.unregister = (governor) ->
  debug 'unregister'
  governor.removeListener 'state', onStateChanged
  governor.removeListener 'error', onError
