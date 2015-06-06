
AMQPStats = require 'amqp-stats'
debug = require('debug')('guv:rabbitmq')

exports.getStats = (config, callback) ->
  options =
    username: config.amqp_user
    password: config.amqp_password
    hostname: config.amqp_host # includes port
    protocol: "https"
  amqp = new AMQPStats options
  amqp.queues (err, res, queues) ->
    debug 'got', err, queues
    return callback err if err
    details = {}
    stats = {}
    for queue in queues
      details[queue.name] = queue
      stats[queue.name] = queue.messages_ready
    return callback null, stats, details
