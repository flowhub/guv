
chai = require 'chai' if not chai
path = require 'path'
{ exec } = require 'child_process'

guv_heroku_workerstats = (logfile, started, callback) ->
  node = 'node'
  prog = path.join __dirname, '..', 'bin', 'guv-heroku-workerstats'
  cmd = "#{node} #{prog} --started #{started} #{logfile}"
  return exec cmd, callback

describe 'guv-heroku-workerstats', () ->

  describe 'logfile without data', ->
    it 'should error with no startups found'

  # Sample < 10 (adjustable with --min-sample)?
  describe 'logfile with too little data', ->
    it 'should error with too few startups found'

  describe 'logfile with plenty data', ->
    it 'should return JSON with stats'
