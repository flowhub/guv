

chai = require 'chai'

guv = require '..'
mocks = require './mocks'
mocks.enable = true

describe 'Statuspage.io metrics', ->
  governor = null
  
  before () ->
    mocks.startRecord()

  after () ->
    mocks.stopRecord()

  # Happy cases
  describe 'enabled', ->
    c = \
    """
    '*': { app: 'guv-test', statuspage: 'statuspage-pageid-113'}
    my: {queue: 'myrole.IN', worker: web, metric: 'statuspage-metricid-990'}
    """
    cfg = guv.config.parse c
    beforeEach (done) ->
      process.env['STATUSPAGE_API_TOKEN'] = 'statuspage-api-token-444'
      governor = new guv.governor.Governor cfg
      guv.statuspage.register governor, cfg
      chai.expect(cfg['*'].broker).to.include 'amqp://'
      done()

    afterEach (done) ->
      guv.statuspage.unregister governor, cfg
      governor.stop()
      done()

    describe 'when state changes', ->
      it 'should report pending jobs', (done) ->
        mocks.RabbitMQ.setQueues { 'myrole.IN': { 'messages': 1000 } }
        mocks.Heroku.setCurrentWorkers 'guv-test', { 'web': 0 }
        postMetrics = mocks.StatusPageIO.expectMetric cfg['*'].statuspage, cfg.my.metric, 1000
        setWorkers = mocks.Heroku.expectWorkers 'guv-test', { 'web': cfg.my.maximum }

        governor.once 'error', (err) ->
          console.log err.stack if err
          chai.expect(err).to.not.exist
        governor.once 'state', (state) ->
          setTimeout ->
            postMetrics.done()
            setWorkers.done()
            done()
          , 500
        governor.start()

