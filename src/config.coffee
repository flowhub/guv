
debug = require('debug')('guv:config')
gaussian = require 'gaussian'
url = require 'url'
peg = require 'pegjs'
fs = require 'fs'
path = require 'path'
parser = peg.buildParser fs.readFileSync (path.join __dirname, '..', 'config.peg') ,'utf-8'

calculateTarget = (config) ->

  # Calculate the point which the process completes
  # the desired percentage of jobs within
  debug 'calculate target', config

  tolerance = (100-config.percentile)/100
  mean = config.processing
  variance = config.stddev*config.stddev
  d = gaussian mean, variance
  ppf = -d.ppf(tolerance)
  distance = mean+ppf

  # TODO: throw Error on impossible config

  # Shift the point up till hits at the specified deadline
  # XXX: Is it a safe assumption that variance is same for all
  return config.deadline-distance


jobsInDeadline = (config) ->
  return config.target / config.process_time


# Syntactical part
parse = (str) ->
  try
    return parser.parse str
  catch e
    if e.name == 'SyntaxError'
      # Enrich message with where it occurred
      orig = e.message.replace('SyntaxError: ', '')
      e.message = "SyntaxError: line #{e.line},column #{e.column} #{orig}"
    throw e

configFormat = () ->
  varFormat =
    [ 'short', 'name', 'description', 'unit', 'default' ]
  varList = [

    # system-unique process parameters
    [ 'p', 'processing', 'Mean job processing time', 'seconds', 10.0 ]
    [ null, 'stddev', 'Standard deviation (1σ) of job processing time: 68% completed within -+ this.', 'seconds', '50% of mean processing time' ]
    [ 'd', 'deadline', 'Time practically all jobs should be completed within.', 'seconds', 60.0 ]
    [ null, 'boot', 'Mean boot time. From adding worker to processing jobs', 'seconds', 30.0 ]

    # worker limits
    [ 'max', 'maximum', 'Maximum amount of workers', 'N workers', 5 ]
    [ 'min', 'minimum', 'Minimum amount of workers', 'N workers', 1 ]

    # names
    [ 'w', 'worker', 'Worker name (dyno role)', 'string', 'role name' ]
    [ 'q', 'queue', 'Queue name', 'string', 'role name' ]
    [ null, 'app', 'Application name (ie on Heroku)', 'string', 'GUV_APP envvar' ]
    [ null, 'broker', 'Broker (ie RabbitMQ) URL', 'url', 'CLOUDAMQP_URL or GUV_BROKER envvar' ]

    # derived/advanced process parameters
    [ null, 'percentile', ' ', '%', 99 ]
    [ null, 'target', ' ', 'seconds', 'Calculated based on process time and variance, to meet percentile and deadline.' ]

  ]
  format =
    shortoptions: {}
    options: {}
  for v in varList
    o = {}
    varFormat.forEach (field, i) ->
      o[field] = v[i]
    o.type = 'string'
    o.type = 'number' if o.unit in [ 'N workers', 'seconds', '%' ]
    format.options[o.name] = o
    format.shortoptions[o.short] = o if o.short

  return format

addDefaults = (format, role, c) ->

  for name, option of format.options
    continue if typeof option.default == 'string'
    c[name] = option.default if not c[name]?

  # TODO: make these functions with a toString, declared in varList?
  c.stddev = c.processing*0.5 if not c.stddev
  c.target = calculateTarget c if not c.target

  c.broker = process.env['GUV_BROKER'] if not c.broker
  c.broker = process.env['CLOUDAMQP_URL'] if not c.broker
  if role != '*'
    c.worker = role if not c.worker
    c.queue = role if not c.queue

  return c

normalize = (role, vars, globals) ->
  format = configFormat()
  retvars = {}

  # Make all globals available on each role
  # Note: some things don't make sense be different per-role, but simpler this way
  for k, v of globals
    retvars[k] = v

  for name, val of vars
    # Lookup canonical long name from short
    name = format.shortoptions[name].name if format.shortoptions[name]?

    # Defined var
    f = format.options[name]
    if f?.type == 'number'
      val = parseFloat(val)

    retvars[name] = val

  # Inject defaults
  retvars = addDefaults format, role, retvars

  return retvars

parseConfig = (str) ->
  parsed = parse str
  config = {}

  # Extract globals first, as they will be merged into individual roles
  globalRole = '*'
  parsed[globalRole] = {} if not parsed[globalRole]
  config[globalRole] = normalize globalRole, parsed[globalRole], {}

  for role, vars of parsed
    continue if role == globalRole
    config[role] = normalize role, vars, config[globalRole]

  return config

exports.parse = parseConfig
exports.parseOnly = parse
exports.defaults = addDefaults
