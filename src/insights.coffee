
Insights = require 'node-insights'
async = require 'async'
debug = require('debug')('guv:insights')

getTimeIntervals = (start, end, intervalMinutes) ->
  # use milliseconds Unix epoch time for calculations
  startT = start.getTime()
  endT = end.getTime()
  intervalT = intervalMinutes*60*1000
  differenceT = (endT - startT)

  intervals = []
  nIntervals = Math.ceil(differenceT/intervalT)
  for i in [0...nIntervals]
    s = startT + intervalT*i
    e = startT + intervalT*(i+1)
    intervals.push
      start: new Date(s)
      end: new Date(e)
  return intervals

getScaleEventsChunk = (insights, start, end, app, fields, event, callback) ->
  start = start.toISOString()
  end = end.toISOString()

  limit = 999
  query = "SELECT #{fields} FROM #{event}"
  query += " WHERE appName = '#{app}'" if app
  query += " SINCE '#{start}' UNTIL '#{end}'"
  query += " LIMIT #{limit}"
  debug 'query', query
  insights.query query, (err, body) ->
    return callback err if err
    return callback new Error "#{body.error}" if body.error

    return callback new Error 'Number of events for interval hit max limit' if body.performanceStats.matchCount >= limit
    results = body.results[0].events
    return callback new Error 'No results returned' if not results? # empty array is fine though

    return callback null, results

getScaleEvents = (options, callback) ->

  insights = new Insights options
  # unfortunately, New Relic insights does not allow more than 1000 results per query (max LIMIT)
  # OFFSET support also seems pretty broken: offset+limit cannot be more than 1000
  # so we subdivide our desired period into many small chunks, (hopefully) smaller than this limit

  # build subqueries
  queries = []
  end = options.end
  start = new Date (end.getTime()-options.period*24*60*60*1000)
  queries = getTimeIntervals start, end, options.queryInterval

  # execute queries
  getChunk = (period, cb) ->
    return getScaleEventsChunk insights, period.start, period.end, options.app, options.fields, options.event, cb

  debug "Executing #{queries.length} over #{options.period} days"
  throw new Error "Extremely high number of queries needed, over 3k: #{queries.length}" if queries.length > 3000
  async.mapLimit queries, options.concurrency, getChunk, (err, chunks) ->
    return callback err if err

    # flatten list
    res = []
    for chunk in chunks
      for r in chunk
        res.push r
    return callback null, res

parse = (args) ->
  addApp = (app, list) ->
    list.push app
    return list

  program = require 'commander'
  program
    .option('--query-key <hostname>', 'Query Key to access New Relic Insights API', String, '')
    .option('--account-id <port>', 'Account ID used to access New Relic Insights API', String, '')
    .option('--app <app>', 'App name in New Relic to query for.', String, '')
    .option('--period <days>', 'Number of days to get data for', Number, 7)
    .option('--fields <one,two>', 'Fields to collect. Comma separated.', String, '*')
    .option('--event <EventName>', 'Event to query for', String, 'GuvScaled')
    .option('--end <DATETIME>', 'End time of queried period.', String, 'now')
    .option('--query-interval <minutes>', 'How big chucks to request at a time', Number, 30)
    .option('--concurrency <N>', 'Number of concurrent commands/subprocesses', Number, 5)
    .parse(args)

normalize = (options) ->
  options.accountId = process.env.NEW_RELIC_ACCOUNT_ID if not options.accountId
  options.queryKey = process.env.NEW_RELIC_QUERY_KEY if not options.queryKey
  if options.end == 'now' or not options.end
    options.end = new Date()
  else
    options.end = new Date options.end
  return options

exports.main = main = () ->
  options = parse process.argv
  options = normalize options

  getScaleEvents options, (err, results) ->
    throw err if err
    console.log JSON.stringify(results, null, 2)


main() if not module.parent

