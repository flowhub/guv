
debug = require('debug')('guv:main')

config = require './config'
heroku = require './heroku'
governor = require './governor'

exports.main = () ->

  # FIXME: add commandline options
  cfgstr = process.env['GUV_CONFIG']

  heroku.dryrun = true
  cfg = config.parse cfgstr
  guv = new governor.Governor cfg

  guv.start()

###
  guv.runOnce (err, state) ->
    throw err if err
    debug 'run once', state
###
