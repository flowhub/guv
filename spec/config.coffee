
chai = require 'chai' if not chai
yaml = require 'js-yaml'
guv = require '..'
fs = require 'fs'
path = require 'path'

parseTest = (test) ->
  describe "#{test.name}", () ->
    assertion = if test.error? then "should error" else "should succeed"

    it assertion, () ->
      if test.error?
        parse = () ->
          guv.config.parse test.input
        chai.expect(parse).to.throw test.error.mention
        chai.expect(parse).to.throw "line #{test.error.line}"
        chai.expect(parse).to.throw "column #{test.error.column}"
      else
        actual = guv.config.parse test.input
        chai.expect(actual).to.eql test.result

describe 'Config parsing', () ->
  try
    tests = yaml.safeLoad fs.readFileSync (path.join __dirname, 'configs.yaml'), 'utf-8'
    tests.forEach parseTest
  catch e
    console.log 'ERROR parsing test file'
    console.log e
    throw e
