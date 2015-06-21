
chai = require 'chai' if not chai
yaml = require 'js-yaml'
guv = require '..'
fs = require 'fs'
path = require 'path'
{ exec } = require 'child_process'

guv_validate = (configstr, callback) ->
  prog = path.join __dirname, '..', 'bin', 'guv-validate'
  cmd = "#{prog} --config '#{configstr}'"
  return exec cmd, callback

validityTest = (test) ->
  describe "validating #{test.name}", () ->
    errCodeAssertion = if test.invalid? then "fails with non-zero returncode" else "passes with returncode 0"
    messageAssertion = if test.invalid? then "error message on stdout" else "no error message"
    if not (test.invalid or test.valid)
      errCodeAssertion = 'missing .valid or .invalid marker'
      messageAssertion = 'missing .valid or .invalid marker'
      itOrSkip = it.skip
    else
      itOrSkip = it


    err = null
    stderr = null
    stdout = null
    before (done) ->
      guv_validate test.input, (e, stdo, stde) ->
        err = e
        stderr = stde
        stdout = stdo
        done()

    itOrSkip errCodeAssertion, () ->
      if test.invalid?
        chai.expect(err).to.exist
        chai.expect(err.code).to.not.equal 0
      else
        chai.expect(err).to.not.exist

    itOrSkip messageAssertion, () ->
      if test.invalid?
        chai.expect(stdout.toLowerCase()).to.contain test.invalid
        chai.expect(stderr).to.equal ''
      else
        chai.expect(stdout).to.equal ''
        chai.expect(stderr).to.equal ''


describe 'guv-validate', () ->
  try
    tests = yaml.safeLoad fs.readFileSync (path.join __dirname, 'configs.yaml'), 'utf-8'
  catch e
    console.log 'ERROR parsing test file'
    console.log e
    throw e
  tests.forEach (test) ->
    if test.valid or test.invalid
      validityTest test
