#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

debug = require('debug')('guv:statuspage')
request = require 'request'

common = require './common'

unixTimestamp = () ->
  return Math.round((new Date()).getTime() / 1000)

postMetric = (config, metric, value, callback) ->
  options =
    method: 'POST'
    url: "#{config.api_base}/pages/#{config.page_id}/metrics/#{metric}/data.json"
    headers:
      'Authorization': "OAuth #{config.api_key}"
    json:
      data:
        timestamp: unixTimestamp()
        value: value
  
  debug 'postmetric', options.url, value
  request options, (err, response, body) ->
    return callback err if err
    return callback new Error("HTTP #{response.statusCode}: #{JSON.stringify(body)}") if response.statusCode != 201
    return callback null

postMetrics = (config, metrics, callback) ->
  debug 'post metrics', Object.keys(metrics)
  f = (key, value, cb) ->
    return postMetric config, key, value, cb
  return common.mapDictionaryAsync metrics, f, callback

onStateChanged = (state, config) ->
  metrics = {}
  debug 'state', state
  for rolename, data of state
    metrics[data.metric] = data.current_jobs if data.metric
  postMetrics config, metrics, (err) ->
    debug 'error', err if err

onError = () ->
  # TODO: implement

exports.register = (governor, guvconfig) ->
  debug 'register'

  config =
    api_base: 'https://api.statuspage.io/v1'
    page_id: guvconfig['*'].statuspage
    api_key: process.env['STATUSPAGE_API_TOKEN']
  enabled = config.page_id and config.api_key
  debug 'enabled?', enabled

  if enabled
    governor.on 'state', (state) ->
      onStateChanged state, config
    governor.on 'error', onError

exports.unregister = (governor) ->
  debug 'unregister'

