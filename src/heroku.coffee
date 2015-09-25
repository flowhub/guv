#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:heroku')
Heroku = require 'heroku-client'
child = require 'child_process'
async = require 'async'

exports.dryrun = false

exports.setWorkers = (config, workers, callback) ->
  options =
    token: process.env['HEROKU_API_KEY']
  heroku = new Heroku options

  # sort workers into belonging app/formation
  formations = {}
  for w in workers
    formations[w.app] = [] if not formations[w.app]
    formations[w.app].push { process: w.role, quantity: w.quantity }

  scaleFormation = (appname, cb) ->
    formation = formations[appname]
    heroku.apps(appname)
        .formation()
        .batchUpdate(updates: formation, cb)

  return callback null if exports.dryrun
  debug 'scaling', workers
  appnames = Object.keys formations
  async.map appnames, scaleFormation, (err, res) ->
    debug 'scaled returned', err, res
    return callback err, res

