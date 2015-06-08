
debug = require('debug')('guv:scale')

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
  debug 'estimate', estimate
  workers = Math.ceil(estimate)
  # TODO: estimate higher than max should be a warning
  # TODO: add code for estimating how long it will take to catch up (given feed rate estimates)
  workers = bound workers, config.minimum, config.maximum
  debug 'bounded', workers
  return workers

exports.scale = scale

