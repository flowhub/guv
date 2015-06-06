
heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'
config = require './config'

exports.main = () ->
  cfg =
    process_time: 1000
    qos_deadline: 10000
    worker_maximum: 1
    heroku_app: 'imgflo'

  cfg = config.defaults cfg

  rabbitmq.getStats cfg, (err, queues) ->
    throw err if err
    console.log queues

    # TODO: should be declared in config
    jobs = queues['fbp']
    workers = scale.scale cfg, jobs

    console.log 'target', cfg.target
    console.log 'jobs', jobs
    console.log 'workers', workers

    heroku.dryrun = true
    # TODO: should be declared in config
    heroku.setWorkers cfg, 'processing', workers, (err) ->
      console.log 'heroku.setWorkers', err
