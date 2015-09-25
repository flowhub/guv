#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:validate')
program = require 'commander'
fs = require 'fs'

config = require './config'

parse = (argv) ->
  program
    .option('-c --config <string>', 'Configuration string', String, '')
    .option('-f --file <FILE.guv>', 'Configuration file', String, '')
    .parse(argv)

# TODO: validate that variables used are known
# TODO: validate that config is not  impossible to realise

normalize = (options) ->
  options.config = process.env['GUV_CONFIG'] if not options.config
  options.config = fs.readFileSync options.file, 'utf-8' if options.file
  return options

# Throws if invalid
validate = (options) ->
  throw new Error 'Configuration is empty' if not options.config

  cfg = config.parse options.config


exports.main = () ->

  options = parse process.argv
  options = normalize options
  try
    validate options
  catch e
    console.log e.message
    process.exit(1)

  process.exit(0)
