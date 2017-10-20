
chai = require 'chai'
async = require 'async'

guv = require '..'
mocks = require './mocks'
mocks.enable = true

describe 'Governor', ->
  governor = null
  
  before () ->
    cfg = guv.config.parse ""
    broker = cfg['*'].broker
    # check that required envvars for the tests
    chai.expect(broker, 'GUV_BROKER envvar not set').to.exist
    chai.expect(broker).to.include 'amqp://'
    chai.expect(process.env['HEROKU_API_KEY'], 'HEROKU_API_KEY envvar not set').to.exist
    mocks.startRecord()

  after () ->
    mocks.stopRecord()

  # Happy cases
  describe 'is happy', ->
    c = \
    """
    '*': { app: 'guv-test' }
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
        mocks.Heroku.setCurrentWorkers 'guv-test', { web: 1 }
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
        mocks.Heroku.setCurrentWorkers 'guv-test', { web: 0 }
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
      setWorkers = null

      it 'should scale up quickly then slowly down again', (done) ->
        governor.once 'error', (err) ->
          chai.expect(err, JSON.stringify(err) ).to.not.exist

        series = [
          { messages: 0, current: 99, next: cfg.my.minimum } # filling up history
          { messages: 0, current: cfg.my.minimum, next: null }
          { messages: 0, current: cfg.my.minimum, next: null }
          { messages: 0, current: cfg.my.minimum, next: null }
          { messages: 100, current: cfg.my.minimum, next: cfg.my.maximum } # fast up
          { messages: 0, current: cfg.my.maximum, next: null } # no-op for 120 seconds, 4 iterations
          { messages: 0, current: cfg.my.maximum, next: null }
          { messages: 0, current: cfg.my.maximum, next: null }
          { messages: 0, current: cfg.my.maximum, next: null }
          { messages: 0, current: cfg.my.maximum, next: cfg.my.minimum } # down
        ]
        series = series.map (s, idx) ->
          s.name = "iteration #{idx} of #{series.length}"
          return s

        iteration = (data, callback) ->

          setTimeout () ->
            # prep this iteration
            mocks.Heroku.setCurrentWorkers 'guv-test', { web: data.current }
            mocks.RabbitMQ.setQueues { 'myrole.IN': { 'messages': data.messages }}
            if data.next?
              setWorkers = mocks.Heroku.expectWorkers 'guv-test', { 'web': data.next }
            else
              setWorkers = null

            # run
            governor.runOnce (err, state) ->
              return callback err if err

              # verify
              try
                if setWorkers
                  setWorkers.done()
              catch e
                return callback e if e
              return callback null, state

          , 10

        async.mapSeries series, iteration, (err) ->
          return done err

  # Complicated config
  describe 'complicated config', ->
    c = \
    """
    '*': { app: 'guv-test' }
    my: { queue: 'myrole.IN', worker: web, minimum: 0, max: 1 }
    ours: { queue: 'ours.IN', worker: web, minimum: 1, max: 1, app: 'other' }
    """
    cfg = guv.config.parse c
    beforeEach (done) ->
      governor = new guv.governor.Governor cfg
      done()

    beforeEach (done) ->
      governor.stop()
      done()

    describe 'scales correctly', ->
      it 'should scale both correctly', (done) ->
        mocks.Heroku.setCurrentWorkers 'guv-test', { web: 0 }
        mocks.Heroku.setCurrentWorkers 'other', { web: 0 }
        mocks.RabbitMQ.setQueues
          'myrole.IN':
            'messages': 0
          'ours.IN':
            'messages': 100
        setWorkers1 = mocks.Heroku.expectWorkers 'guv-test',
          'web': cfg.my.minimum

        setWorkers2 = mocks.Heroku.expectWorkers 'other',
          'web': cfg.ours.maximum

        governor.once 'error', (err) ->
          chai.expect(err).to.not.exist

        governor.once 'state', (state) ->
          chai.expect(state).to.include.keys 'my'
          chai.expect(state).to.include.keys 'ours'
          chai.expect(state.my.current_jobs).to.equal 0
          chai.expect(state.my.new_workers).to.equal cfg.my.minimum
          chai.expect(state.ours.new_workers).to.equal cfg.ours.maximum
          setWorkers1.done()
          setWorkers2.done()
          done()
        governor.start()

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
        mocks.Heroku.setCurrentWorkers 'guv-test', { correctworker: 99 }
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

