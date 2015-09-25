
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

  # Happy cases
  describe 'is happy', ->
    c = \
    """
    '*': { app: 'guv-test'}
    my: {queue: 'myrole.IN', worker: web, minimum: 0, max: 1}
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
            'messages': 0
        setWorkers = mocks.Heroku.expectWorkers 'guv-test',
          'web': cfg.my.minimum

        governor.once 'error', (err) ->
          chai.expect(err).to.not.exist

        governor.once 'state', (state) ->
          chai.expect(state).to.include.keys 'my'
          chai.expect(state.my.current_jobs).to.equal 0
          chai.expect(state.my.new_workers).to.equal cfg.my.minimum
          setWorkers.done()
          done()
        governor.start()

    describe 'lots of messages in queue', ->
      it 'should scale to maximum', (done) ->
        mocks.RabbitMQ.setQueues
          'myrole.IN':
            'messages': 1000
        setWorkers = mocks.Heroku.expectWorkers 'guv-test',
          'web': cfg.my.maximum

        governor.once 'error', (err) ->
          chai.expect(err).to.not.exist

        governor.once 'state', (state) ->
          chai.expect(state).to.include.keys 'my'
          chai.expect(state.my.current_jobs).to.equal 1000
          chai.expect(state.my.new_workers).to.equal cfg.my.maximum
          setWorkers.done()
          done()
        governor.start()

    describe 'lots of messages then less', ->
      it 'should first scale up'
      it 'then scale down again'


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
      newState = null
      cfg = null
      setWorkers = null

      it 'should emit error', (done) ->
        c = """
        '*': { app: 'guv-test'}
        wrongqueue: {queue: 'myrole.NONEXIST', worker: wrongworker, minimum: 0, max: 1}
        correctqueue: {queue: 'myrole.IN', worker: correctworker, minimum: 0, max: 1}
        """
        cfg = guv.config.parse c
        gov = new guv.governor.Governor cfg
        mocks.RabbitMQ.setQueues { 'myrole.IN': { 'messages': 334 } }
        setWorkers = mocks.Heroku.expectWorkers 'guv-test', { 'correctworker': cfg.correctqueue.maximum }

        gov.once 'error', (err) ->
          chai.expect(err).to.exist
          chai.expect(err.message).to.contain cfg.wrongqueue.queue
          done()
        gov.once 'state', (state) ->
          newState = state
        gov.start()

      it 'should still send state update', ->
        chai.expect(newState).to.exist
        chai.expect(newState).to.have.keys ['correctqueue', 'wrongqueue']
        chai.expect(newState.correctqueue.new_workers).to.equal cfg.correctqueue.maximum

      it 'should still scale the other workers', () ->
        setWorkers.done()

