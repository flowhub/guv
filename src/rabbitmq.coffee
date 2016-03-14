#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

AMQPStats = require 'amqp-stats'
debug = require('debug')('guv:rabbitmq')
url = require 'url'

amqpOptions = (str) ->
  o = {}
  u = url.parse str
  if u.auth
    [ user, password ] = u.auth.split ':'
    o.username = user
    o.password = password
  o.hostname = u.host # includes port
  o.protocol = 'https'
  return o

# http://hg.rabbitmq.com/rabbitmq-management/raw-file/9b44a7aca551/priv/www/doc/stats.html
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
      details[queue.name].fillrate = queue.message_stats?.publish_details?.rate
      details[queue.name].drainrate = queue.message_stats?.ack_details?.rate
      stats[queue.name] = queue.messages
    return callback null, stats, details
