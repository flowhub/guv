
statistics = require 'simple-statistics'
gaussian = require 'gaussian'

# TODO: move config handling to separate file
calculateTarget = (config) ->

  console.log config

  # Calculate the point which the process completes
  # the desired percentage of jobs within
  tolerance = (100-config.qos_percent)/100
  mean = config.process_time
  stddev = config.process_stddev
  variance = stddev*stddev
  d = gaussian mean, variance
  ppf = -d.ppf(tolerance)
  distance = mean+ppf

  # Shift the point up till hits at the specified deadline
  # XXX: Is it a safe assumption that variance is same for all
  return config.qos_deadline-distance

defaults = (c) ->
  # Mandatory
  throw new Error 'config.qos_deadline must be set!' if not c.qos_deadline
  throw new Error 'config.process_time estimate must be set' if not c.process_time

  # Percentage of jobs that should be completed within the deadline
  c.qos_percent = 99 if not c.qos_percent
  # Assume 68% of jobs complete within -+ 50%
  c.process_stddev = c.process_time*0.5 if not c.process_stddev
  # Set time to adjust towards based on statistical model
  c.target = calculateTarget c if not c.target

  return c

jobsInDeadline = (config) ->
  return config.target / config.process_time


exports.defaults = defaults
