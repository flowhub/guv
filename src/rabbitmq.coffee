
AMQPStats = require 'amqp-stats'
debug = require('debug')('guv:rabbitmq')

exports.getStats = (config, callback) ->
  options =
    username: config.amqp_username
    password: config.amqp_password
    hostname: config.amqp_host # includes port
    protocol: "https"
  debug 'options', options
  amqp = new AMQPStats options
  amqp.queues (err, res, queues) ->
    debug 'got queue info', err, queues.length
    return callback err if err
    details = {}
    stats = {}
    for queue in queues
      details[queue.name] = queue
      stats[queue.name] = queue.messages_ready
    return callback null, stats, details
