
nock = null
path = require 'path'
fs = require 'fs'

recorded = require './fixtures/nocks.json'
record = process.env['NOCK_RECORD']
exports.enable = false

clone = (obj) ->
  return JSON.parse JSON.stringify obj

class Heroku
  constructor: () ->

exports.Heroku = Heroku

exports.RabbitMQ =
  setQueues: (overrides={}) ->
    return if not exports.enable

    r = clone recorded[0]
    for queue in r.response
      override = overrides[queue.name]
      for k, v of override
        queue[k] = v

    scope = require('nock')(r.scope)
      .get(r.path)
      .reply(r.status, r.response)
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
  console.log "#{rets.legnth} captured HTTP requests written to #{outpath}"
