
heroku = require './heroku'
rabbitmq = require './rabbitmq'
scale = require './scale'


exports.main = () ->
  config =
    process_time: 1000
    qos_deadline: 4000
  config = scale.defaults config

  console.log 'target', config.target

