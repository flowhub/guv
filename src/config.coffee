#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:config')
gaussian = require 'gaussian'
url = require 'url'
yaml = require 'js-yaml'
fs = require 'fs'
path = require 'path'

schemas =
  roleconfig: require '../schema/roleconfig.json'
  config: require '../schema/config.json'

calculateTarget = (config) ->
  # Calculate the point which the process completes
  # the desired percentage of jobs within
  debug 'calculate target for', config.processing, config.stddev, config.deadline

  tolerance = (100-config.percentile)/100
  mean = config.processing
  variance = config.stddev*config.stddev
  d = gaussian mean, variance
  ppf = -d.ppf(tolerance)
  distance = mean+ppf

  # Shift the point up till hits at the specified deadline
  # XXX: Is it a safe assumption that variance is same for all
  target = config.deadline-distance
  return target


jobsInDeadline = (config) ->
  return config.target / config.process_time


# Syntactical part
parse = (str) ->
  o = yaml.safeLoad str
  o = {} if not o
  return o

serialize = (parsed) ->
  return yaml.safeDump parsed

clone = (obj) ->
  return JSON.parse JSON.stringify obj

configFormat = () ->
  format =
    shortoptions: {}
    options: {}
  for name, value of schemas.roleconfig.properties
    o = clone value
    throw new Error "Missing type for config property #{name}" if not o.type
    o.name = name
    format.options[name] = o
    format.shortoptions[o.shorthand] = o if o.shorthand

  return format

addDefaults = (format, role, c) ->
  for name, option of format.options
    continue if typeof option.default == 'string'
    c[name] = option.default if not c[name]?

  # TODO: have a way of declaring these functions in JSON schema?
  c.statuspage = process.env['STATUSPAGE_ID'] if not c.statuspage
  c.broker = process.env['GUV_BROKER'] if not c.broker
  c.app = process.env['GUV_APP'] if not c.app
  c.broker = process.env['CLOUDAMQP_URL'] if not c.broker
  c.errors = [] # avoid shared ref
  if role != '*'
    c.worker = role if not c.worker
    c.queue = role if not c.queue
    c.stddev = c.processing*0.5 if not c.stddev
    c.target = calculateTarget c if not c.target

    if c.target <= c.processing
      e = new Error "Target #{c.target.toFixed(2)}s is lower than processing time #{c.processing.toFixed(2)}s. Attempted deadline #{c.deadline}s."
      debug 'target error', e
      c.errors.push e # for later reporting
      c.target = c.processing+0.01 # do our best

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

validateConfig = (str, options) ->
  tv4 = require 'tv4'
  tv4.addSchema schemas.roleconfig.id, schemas.roleconfig
  tv4.addSchema schemas.config.id, schemas.config
  parsed = parse str

  options.allowKeys = [] if not options.allowKeys

  format = configFormat()
  for role, vars of parsed
    for name, val of vars
      # Lookup canonical long name from short
      # XXX: a bit hacky way to avoid duplicate definitions in the JSON schema
      if format.shortoptions[name]?
        longname = format.shortoptions[name].name
        vars[longname] = val
        delete vars[name]

      if name in options.allowKeys
        delete vars[name]

  checkRecursive = false
  banUnknownProperties = true
  result = tv4.validateMultiple parsed, schemas.config.id, checkRecursive, banUnknownProperties
  errors = []
  for e in result.errors
    role = e.dataPath.split('/')[1]
    property = e.dataPath.split('/')[2]
    err = new Error "#{e.message} for #{e.dataPath}"
    errors.push err

  return errors

estimateRates = (cfg) ->
  rates = {}
  for role, c of cfg
    continue if role == '*'
    rate = c.concurrency * c.maximum * (1 / c.processing)
    rates[role] = rate

  return rates

main = () ->
  p = process.argv[2]
  f = fs.readFileSync p, 'utf-8'
  parsed = parseConfig f
  rates = estimateRates parsed
  for role, rate of rates
    perMinute = (rate*60).toFixed(2)
    padded = ("                                     " + role).slice(-40)
    console.log "#{padded}: #{perMinute} jobs/minute"

main() if not module.parent

exports.validate = validateConfig
exports.parse = parseConfig
exports.parseOnly = parse
exports.serialize = serialize
exports.defaults = addDefaults
