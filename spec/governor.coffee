
guv = require '..'

describe 'Governor', ->

  cfg = """
  *{app=guv-test}
  my{p=60,deadline=240,queue=myrole.INPUT,worker=myworker}
  """

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
  describe 'no messages in queue', ->
    it 'should scale to minimum'

  describe 'lots of messages in queue', ->
    it 'should scale to maximum'

  describe 'lots of messages then less', ->
    it 'should first scale up'
    it 'then scale down again'
