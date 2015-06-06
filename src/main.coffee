
debug = require('debug')('guv:main')

heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'
config = require './config'

checkAndScale = (cfg, role, callback) ->
  rabbitmq.getStats cfg, (err, queues) ->
    role.current_jobs = null
    return callback err if err
    console.log err, queues

    role.current_jobs = queues[role.amqp_queue]
    return callback new Error "Could not get data for queue: #{role.amqp_queue}" if not role.current_jobs?
    workers = scale.scale cfg, role.current_jobs

    heroku.setWorkers cfg, role.heroku_dyno, workers, (err) ->
      role.current_workers = null
      return callback err if err

      state = {}
      role.workers = workers
      state[role.id] = role
      return callback null, state


class Governor
  constructor: (c) ->
    @config = config.defaults c

    @interval = null

  start: () ->
    runFunc = () =>

    seconds = 60*1000 
    interval = runInterval runFunc, 30*seconds
    runFunc() # do first iteration right now

  stop: () ->
    clearInterval @interval if @interval

  runOnce: (callback) ->

    # FIXME: unhardcode, add support for multiple processes/queues
    role =
      id: 'processing'
      amqp_queue: 'worker.JOB'
      heroku_dyno: 'processing'
      current_workers: null
      current_jobs: null
    checkAndScale @config, role, callback


exports.main = () ->
  cfg =
    process_time: 1000
    qos_deadline: 10000
    worker_maximum: 1
    heroku_app: 'imgflo'

  heroku.dryrun = true
  guv = new Governor cfg
  guv.runOnce (err, state) ->
    throw err if err
    console.log state

