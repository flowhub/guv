#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:validate')
program = require 'commander'
fs = require 'fs'

config = require './config'

parse = (argv) ->
  addAllowKey = (key, list) ->
    list.push key
    return list

  program
    .option('-c --config <string>', 'Configuration string', String, '')
    .option('-f --file <FILE.guv>', 'Configuration file', String, '')
    .option('--allow-key <configkey>', 'Non-standard config key to allow', addAllowKey, [])
    .parse(argv)


normalize = (options) ->
  options.config = process.env['GUV_CONFIG'] if not options.config
  options.config = fs.readFileSync options.file, 'utf-8' if options.file
  return options

# Throws if invalid
validate = (options) ->
  throw new Error 'Configuration is empty' if not options.config

  cfg = config.parse options.config
  validationErrors = config.validate options.config, { allowKeys: options.allowKey }

  errors = []
  for role, c of cfg
    for e in c.errors
      debug 'config error', role, e
      errors.push "\t#{role}: #{e.message}\n"

  for e in validationErrors
    errors.push "\t#{e.message}\n"

  if errors.length
    throw new Error "#{errors.length} config errors:\n #{errors}"

exports.main = () ->

  options = parse process.argv
  options = normalize options
  try
    validate options
  catch e
    console.log e.message
    process.exit(1)

  process.exit(0)
