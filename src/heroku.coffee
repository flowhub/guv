
debug = require('debug')('guv:heroku')

process = require 'child_process'

exports.dryrun = false

exports.setWorkers = (config, role, number, callback) ->

  app = config.heroku_app
  prog = 'heroku'
  args = ['ps:scale', "#{role}=#{number}", "--app", app]

  cmd = prog + ' ' + args.join ' '
  debug 'running', cmd
  return callback null if exports.dryrun
  process.exec cmd, (err, stdout, stderr) ->
    debug 'returned', stdout, stderr
    return callback err if err
    return callback new Error 'heroku: Usage error' if stdout.indexOf('Usage:') != -1
    return callback null
