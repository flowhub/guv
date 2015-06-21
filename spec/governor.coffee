
chai = require 'chai'

guv = require '..'
mocks = require './mocks'
mocks.enable = true

describe 'Governor', ->
  governor = null
  
  before () ->
    # must be set before running tests
    cfg = guv.config.parse ""
    chai.expect(cfg['*'].broker).to.include 'amqp://'
    chai.expect(process.env['HEROKU_API_KEY']).to.have.length.above 10
    mocks.startRecord()

  after () ->
    mocks.stopRecord()

  # Error cases
  describe 'Errors', ->

    describe 'cannot connect to Heroku', ->
      it 'should emit error'
    describe 'specified worker does not exist', ->
      it 'should emit error'
      it 'other workers should be unaffected'

    describe 'cannot connect to RabbitMQ', ->
      it 'should emit error'
    describe 'specified queue does not exist', ->
      it 'should emit error'
      it 'other workers should be unaffected'

  # Happy cases
  describe 'is happy', ->
    c = \
    """
    *{app=guv-test};
    my{queue=myrole.IN,worker=web, minimum=0, max=1};
    """
    cfg = guv.config.parse c
    beforeEach (done) ->
      governor = new guv.governor.Governor cfg
      done()

    beforeEach (done) ->
      governor.stop()
      done()

    describe 'no messages in queue', ->
      it 'should scale to minimum', (done) ->
        mocks.RabbitMQ.setQueues
          'myrole.IN':
            'messages_ready': 0
            'messages': 0

        governor.once 'error', (err) ->
          chai.expect(err).to.not.exist

        governor.once 'state', (state) ->
          chai.expect(state).to.include.keys 'my'
          chai.expect(state.my.current_jobs).to.equal 0
          chai.expect(state.my.new_workers).to.equal cfg.my.minimum
          done()
        governor.start()

    describe 'lots of messages in queue', ->
      it 'should scale to maximum', (done) ->
        mocks.RabbitMQ.setQueues
          'myrole.IN':
            'messages_ready': 1000
            'messages': 1000

        governor.once 'error', (err) ->
          chai.expect(err).to.not.exist

        governor.once 'state', (state) ->
          chai.expect(state).to.include.keys 'my'
          chai.expect(state.my.current_jobs).to.equal 1000
          chai.expect(state.my.new_workers).to.equal cfg.my.maximum
          done()
        governor.start()

    describe 'lots of messages then less', ->
      it 'should first scale up'
      it 'then scale down again'
