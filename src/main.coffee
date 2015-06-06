
heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'

exports.main = () ->
  config =
    process_time: 1000
    qos_deadline: 10000
    worker_maximum: 1
    heroku_app: 'imgflo'

  config = scale.defaults config

  rabbitmq.getStats config, (err, queues) ->
    throw err if err
    console.log queues

    # TODO: should be declared in config
    jobs = queues['fbp']
    workers = scale.scale config, jobs

    console.log 'target', config.target
    console.log 'jobs', jobs
    console.log 'workers', workers

    heroku.dryrun = true
    # TODO: should be declared in config
    heroku.setWorkers config, 'processing', workers, (err) ->
      console.log 'heroku.setWorkers', err
