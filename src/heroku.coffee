
debug = require('debug')('guv:heroku')

process = require 'child_process'

exports.dryrun = false

workerArgs = (workers) ->
  args = []
  for name, number in workers
    args.push "#{role}=#{number}"
  return args

exports.setWorkers = (config, workers, callback) ->

  app = config.app
  prog = 'heroku'
  args = ['ps:scale']
  args = args.concat workerArgs(workers)
  args = args.concat [ "--app", app]

  cmd = prog + ' ' + args.join ' '
  debug 'running', cmd
  return callback null if exports.dryrun
  process.exec cmd, (err, stdout, stderr) ->
    debug 'returned', stdout, stderr
    return callback err if err
    return callback new Error 'heroku: Usage error' if stdout.indexOf('Usage:') != -1
    return callback null
