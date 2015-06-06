

# TODO: account for dyno bootup time
# Proportional scaling model
proportional = (config, queueLength) ->
  waitingTime = queueLength * config.process_time
  availableTime = config.target - config.process_time
  return waitingTime/availableTime

min = (a, b) -> if a < b then a else b
max = (a, b) -> if a > b then a else b
bound = (v, lower, upper) -> return min(max(v, lower), upper)

scale = (config, queueLength) ->
  estimate = proportional config, queueLength
  workers = Math.ceil(estimate)
  # TODO: estimate higher than max should be a warning
  # TODO: add code for estimating how long it will take to catch up (given feed rate estimates)
  workers = bound workers, config.worker_minimum, config.worker_maximum

exports.scale = scale

