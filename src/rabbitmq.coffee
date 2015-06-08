
AMQPStats = require 'amqp-stats'
debug = require('debug')('guv:rabbitmq')
url = require 'url'

amqpOptions = (str) ->
  u = url.parse str
  [ user, password ] = u.auth.split ':'
  o.host = u.host
  o.username = user
  o.password = password
  o.protocol = 'https'
  return o

exports.getStats = (config, callback) ->

  options = amqpOptions config.broker
  debug 'options', options
  amqp = new AMQPStats options
  amqp.queues (err, res, queues) ->
    debug 'got queue info', err, queues?.length
    return callback err if err
    details = {}
    stats = {}
    for queue in queues
      details[queue.name] = queue
      stats[queue.name] = queue.messages_ready
    return callback null, stats, details
