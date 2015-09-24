
debug = require('debug')('guv:main')

config = require './config'
heroku = require './heroku'
governor = require './governor'
newrelic = require './newrelic'
statuspage = require './statuspage'

program = require 'commander'

parse = (argv) ->
  program
    .option('--config <string>', 'Configuration string', String, '')
    .option('--dry-run', 'Configuration string', Boolean, false)
    .option('--oneshot', 'Run once instead of continously', Boolean, false)
    .parse(argv)

exports.main = () ->

  options = parse process.argv
  options.config = process.env['GUV_CONFIG'] if not options.config

  heroku.dryrun = options['dry-run']
  cfg = config.parse options.config
  guv = new governor.Governor cfg
  newrelic.register guv, cfg
  statuspage.register guv, cfg

  console.log 'Using configuration:\n', options.config

  if options.oneshot
    guv.runOnce (err, state) ->
      throw err if err
      console.log state
  else
    guv.on 'error', (err) ->
      console.log 'ERROR:', err
    guv.start()

