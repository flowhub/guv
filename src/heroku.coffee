
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

setWorkersCmd = (config, workers, callback) ->

  app = config.app
  prog = 'heroku'
  args = ['ps:scale']
  args = args.concat workerArgs(workers)
  args = args.concat [ "--app", app]

  cmd = prog + ' ' + args.join ' '
  debug 'running', cmd
  return callback null if exports.dryrun
  child.exec cmd, (err, stdout, stderr) ->
    debug 'returned', stdout, stderr
    return callback err if err
    return callback new Error 'heroku: Usage error' if stdout.indexOf('Usage:') != -1
    return callback null


exports.setWorkers = (config, workers, callback) ->
  options =
    key : process.env['HEROKU_API_KEY']
  client = new Heroku options

  scaleWorker = (name, cb) ->
    quantity = workers[name]
    client.post_ps_scale config.app, name, quantity, (err, res) ->
      return cb err if err
      return cb null
    
  return callback null if exports.dryrun
  debug 'scaling', workers
  async.map Object.keys(workers), scaleWorker, (err, res) ->
    debug 'scaled returned', err
    return callback err

