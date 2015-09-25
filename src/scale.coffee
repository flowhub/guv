#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:scale')
common = require './common'

# TODO: account for dyno bootup time
# Proportional scaling model
proportional = (config, queueLength) ->
  waitingTime = queueLength * config.processing
  availableTime = config.target - config.processing
  return waitingTime/availableTime

min = (a, b) -> if a < b then a else b
max = (a, b) -> if a > b then a else b
bound = (v, lower, upper) -> return min(max(v, lower), upper)

scale = (config, queueLength) ->
  estimate = proportional config, queueLength
  debug 'estimate for', queueLength, estimate
  workers = Math.ceil(estimate)
  # TODO: estimate higher than max should be a warning
  # TODO: add code for estimating how long it will take to catch up (given feed rate estimates)
  workers = bound workers, config.minimum, config.maximum
  debug 'bounded', workers
  return workers

# returns null on no-op
# @history: Array of previous values
scaleWithHistory = (config, name, history, currentWorkers, currentMessages) ->
  ret =
    estimate: null
    next: null

  if history.length and typeof history[0] != 'number'
    throw new Error 'scaleWithHistory sanitycheck failed: history does not have numbers'

  ret.estimate = workers = scale config, currentMessages
  if not currentWorkers?
    # don't know which way we're going, reset to estimate
    debug 'reset to estimate', name, workers
    ret.next = workers
  else if workers > currentWorkers
    # scaling up, act immediately
    ret.next = workers
    debug 'scaling up from,to', name, currentWorkers, workers
  else if workers < currentWorkers
    # scaling down, only act when we're reasonably confident we don't need.
    # This is due to the non-trivial time cost of scaling down/up workers
    #
    # require current prediciton to be lower than everything in current history window
    shouldScale = common.all(history, (e) -> return e <= workers)
    ret.next = workers if shouldScale
    debug 'scaling down?', name, shouldScale, currentWorkers, workers
  else if workers == currentWorkers
    debug 'staying with same'
  else
    throw Error 'scaleWithHistory: Reached what should be unreachable'

  return ret

exports.scale = scale
exports.scaleWithHistory = scaleWithHistory

