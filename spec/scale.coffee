
chai = require 'chai' if not chai
yaml = require 'js-yaml'
guv = require '..'
fs = require 'fs'
path = require 'path'

scaleTest = (test) ->
  describe "#{test.name}", () ->

    it test.expect, () ->
      cfg = guv.config.parse test.config
      actual = guv.scale.scale cfg['*'], test.state.messages
      chai.expect(actual).to.equal test.result


describe 'Scaling', () ->
  try
    tests = yaml.safeLoad fs.readFileSync (path.join __dirname, 'scaletests.yaml'), 'utf-8'
  catch e
    console.log 'ERROR parsing test file'
    console.log e
    throw e
  tests.forEach (test) ->
    scaleTest test
