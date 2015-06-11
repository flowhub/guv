
debug = require('debug')('guv:heroku')
{Heroku} = require "heroku"
child = require 'child_process'
async = require 'async'

exports.dryrun = false

workerArgs = (workers) ->
  args = []
  for name, number in workers
    args.push "#{role}=#{number}"
  return args

exports.setWorkers = (config, workers, callback) ->
  options =
    key : process.env['HEROKU_API_KEY']
  client = new Heroku options

  scaleWorker = (w, cb) ->
    client.post_ps_scale w.app, w.role, w.quantity, (err, res) ->
      return cb err if err
      return cb null
    
  return callback null if exports.dryrun
  debug 'scaling', workers
  async.map workers, scaleWorker, (err, res) ->
    debug 'scaled returned', err
    return callback err

