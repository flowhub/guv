
chai = require 'chai' if not chai
yaml = require 'js-yaml'
guv = require '..'
fs = require 'fs'
path = require 'path'

definedVarsEql = (actual, expected) ->
  # Remove things not defined in expectation
  filtered = {}
  for role, vars of actual
    filtered[role] = {}
    for key, value of vars
      defined = expected[role]?[key]?
      filtered[role][key] = value if defined

  chai.expect(filtered).to.eql expected

parseTest = (test) ->
  describe "parsing #{test.name}", () ->
    assertion = if test.error? then "parsing should error" else "parsing should succeed"

    it assertion, () ->
      if test.error?
        parse = () ->
          guv.config.parseOnly test.input
        chai.expect(parse).to.throw test.error.mention
        chai.expect(parse).to.throw "line #{test.error.line}"
        chai.expect(parse).to.throw "column #{test.error.column}"
      else
        actual = guv.config.parseOnly test.input
        chai.expect(actual).to.eql test.parsed

normalizeTest = (test) ->
  describe "parsing #{test.name}", () ->

    it 'should be normalized', () ->
      actual = guv.config.parse test.input
      definedVarsEql actual, test.config

describe 'Config', () ->
  try
    tests = yaml.safeLoad fs.readFileSync (path.join __dirname, 'configs.yaml'), 'utf-8'
  catch e
    console.log 'ERROR parsing test file'
    console.log e
    throw e
  tests.forEach (test) ->
    if test.parsed or test.error
      parseTest test
    else if test.config
      normalizeTest test
