
debug = require('debug')('guv:spec:mocks')
{ EventEmitter } = require 'events'
nock = null
path = require 'path'
fs = require 'fs'

recorded = require './fixtures/nocks.json'
record = process.env['NOCK_RECORD']
exports.enable = false

clone = (obj) ->
  return JSON.parse JSON.stringify obj

class NoMock
  done: () ->
    # no-op


exports.Heroku =
  expectWorkers: (app, workers) ->
    return new NoMock if not exports.enable

    formation = []
    for name, qty of workers
      formation.push { process: name, quantity: qty }

    scope = require('nock')('https://api.heroku.com')
      .patch("/apps/#{app}/formation", updates: formation)
      .reply(200)

    return scope

exports.RabbitMQ =
  setQueues: (overrides={}) ->
    return new NoMock if not exports.enable

    r = clone recorded[0]
    for queue in r.response
      override = overrides[queue.name]
      for k, v of override
        queue[k] = v

    scope = require('nock')(r.scope)
      .get(r.path)
      .reply(r.status, r.response)
    return scope

exports.StatusPageIO =
  expectMetric: (pageId, metric, value) ->
    return new NoMock if not exports.enable

    matches = (body) ->
      hasTimestamp = typeof(body?.data?.timestamp) == 'number'
      correctValue = body?.data?.value == value
      debug 'statuspage.io metric hit', body, hasTimestamp, correctValue
      return hasTimestamp and correctValue

    scope = require('nock')('https://api.statuspage.io/v1')
      .post("/pages/#{pageId}/metrics/#{metric}/data.json", matches)
      .reply(201)

    return scope

exports.startRecord = () ->
  return if not record

  require('nock').recorder.rec
    output_objects: true
    dont_print: true

exports.stopRecord = () ->
  return if not record

  rets = require('nock').recorder.play()
  json = JSON.stringify rets, null, '  '
  outpath = path.join __dirname, 'fixtures', 'nocks.json'
  fs.writeFileSync outpath, json
  console.log "#{rets.length} captured HTTP requests written to #{outpath}"
