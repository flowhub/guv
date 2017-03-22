
'2017-03-01'

fs = require 'fs'
async = require 'async'
{ exec } = require 'child_process'

# inclusive. [start, end]
daysInPeriod = (start, end) ->
  days = [ ]
  current = new Date start
  while current < end
    days.push current
    current = new Date(current.setDate(current.getDate() + 1))
  return days

haveData = (file, callback) ->
  fs.exists file, (exists) ->
    return callback null, false if not exists
    fs.stat file, (err, stat) ->
      return callback err if err
      hasData = stat.size > 1
      return callback null, hasData

dateOnlyString = (date) ->
  return date.toISOString().split('T')[0]

# never returns Error, instead puts them as .error in returned data
executeDay = (day, args, callback) ->
  date = dateOnlyString day
  file = "#{args.prefix}#{date}#{args.suffix}"
  haveData file, (err, alreadyDone) ->
    return callback null, { file: file, error: err, status: 'failed when checking file'  } if err
    if alreadyDone
      console.log 'SKIP', file
      return callback null, { file: file, status: 'skipped, already done' }
    else
      cmd = args.command.replace '#DATE', date
      cmd += " > #{file}"
      options =
        shell: true
      console.log '$', cmd
      exec cmd, options, (err, stdout, stderr) ->
        status = if err then "FAILED, #{stderr}" else 'SUCCESS'
        console.log '!', file, status
        return callback null, { file: file, error: err, stdout: stdout, stderr: stderr, status: status }

# returns array of an object describing. If has .error, then was a failure
executeOverDays = (args, callback) ->
  days = daysInPeriod args.start, args.end

  async.mapLimit days, 5, (d, cb) ->
    executeDay d, args, cb
  , callback

parse = (args) ->
  program = require 'commander'
  program
    .option('--prefix <PREFIX>', 'Prefix for all files', String, '')
    .option('--suffix <SUFFIX>', 'Suffic for all files', String, '')
    .option('--command <COMMAND>', 'Command to execute for each day.', String, '')
    .option('--start <DATE>', 'Start time of period to run', String, '')
    .option('--end <DATE>', 'End time of period to run', String, 'now')
    .parse(args)

normalize = (args) ->
  throw new Error "--command must be specified" if not args.command
  throw new Error "--start must be specified" if not args.start
  throw new Error "--end must be specified" if not args.end

  args.start = new Date args.start
  args.end = new Date args.end

  return args

main = () ->
  #haveData 'the-grid-api-march18.json', (err, data) ->
  #  console.log 'err', err, data
  args = parse process.argv
  args = normalize args

  executeOverDays args, (err, results) ->
    failures = results.filter (r) -> r.error
    exitCode = failures.length
    if exitCode
      console.log failures
    process.exit exitCode

main() if not module.parent
