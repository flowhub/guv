
{ Governor } = require './governor'
config = require './config'

# note: names lowercased
costsHourly =
  'standard-1x': 0.035 # 25 usd/mnt
  'standard-2x': 0.070 # 50
  'performance-m': 0.350 # 250
  'performance-l': 0.700 # 500
  '1x': 0.050 # legacy
  '2x': 0.100 # legacy
  'px': 0.800 # legacy

calculateCosts = (computeSeconds, dynoType) ->
  costs = {}
  for role, seconds of computeSeconds
    type = dynoType[role]
    type = 'standard-1x' if not type
    type = type.toLowerCase()
    hours = (seconds/(60*60))
    cost = costsHourly[type]*hours
    costs[role] = cost
  return costs

# Accumulate the compute time used
class ComputeTimer
  constructor: () ->
    @accumulated = {} # role -> seconds
    @previousTimes = {} # role -> timestamp
    @previousWorkers = {} # role -> N workers

  addState: (state, times, workers) ->
    for role, s of state
      newTime = times[role]
      actual = workers[role]
      #console.log 'ss', role, s.current_workers
      @accumulated[role] = 0 if not @accumulated[role]?

      ###
      if @previousTimes[role]
        timeDiff = Math.ceil((newTime - @previousTimes[role])/(1000))
        increment = (timeDiff * s.current_workers)
        @accumulated[role] += increment
      if s.new_workers and s.previous_workers
        # compensate for boot-up/shutdown time?
        bootTime = 60
        #console.log 'adding', s.new_workers - s.previous_workers
        change = Math.abs(s.new_workers - s.previous_workers)
        @accumulated[role] += bootTime * change

        if actual? and actual != s.current_workers
          console.log 'no match', role, actual, s.current_workers, s.current_workers-actual
        else
          #console.log 'match'
          null
      ###
      if actual
        if @previousTimes[role] and @previousWorkers[role]
          timeDiff = Math.ceil((newTime - @previousTimes[role])/(1000))
          increment = (timeDiff * @previousWorkers[role])
          @accumulated[role] += increment
        @previousTimes[role] = newTime
        @previousWorkers[role] = actual
    
arrayEquals = (a, b) ->
  A = a.toString()
  B = b.toString()
  return A == B # Lazy

queueDataFromEvents = (cfg, events) ->
  # sort events time-wise
  events = events.sort (a, b) -> (a.timestamp - b.timestamp)

  # calculate full set of queue data, as they would be returned by RabbitMQ
  allRoles = Object.keys(cfg).filter((r) -> r != '*').sort()
  data = []
  lastTimestamp = 0
  lastByRole = {}
  for e in events
    if e.timestamp < lastTimestamp
      console.log 'WARN: unordered event data', e.timestamp, lastTimestamp
    lastByRole[e.role] = e
    lastTimestamp = e.timestamp

    haveRoles = Object.keys(lastByRole).sort()
    #console.log haveRoles, allRoles
    if arrayEquals haveRoles, allRoles
      queues = {}
      timestamps = {}
      workers = {}
      for role, v of lastByRole
        queue = cfg[role].queue
        queues[queue] = v.jobs
        timestamps[role] = v.timestamp
        workers[role] = v.workers

      #console.log 'full', queues, lastByRole
      data.push
        queues: queues
        timestamps: timestamps
        workers: workers
      lastByRole = {}

  return data

# with a given config
# replay a set of GuvScaled events
# invariant:  events are sorted according to increasing time
# determine an initial stable state, where we have internal state for all roles
# from this time on, calculate number of worker-compute-seconds (or minutes) we have
# based on this data, allow calculating cost (per role, per app, total)
#
# TODO: allow filtering on app?
# TODO: store some config identifier into events? hash of normalized config? so we can detect changes
# TODO: allow calculating min and max, costs from a config
# TODO: allow calculating typical costs, given total number of events for period

main = () ->
  # node.js only
  fs = require 'fs'

  [ interpreter, prog, configFile, eventFile ] = process.argv

  c = fs.readFileSync configFile
  cfg = config.parse c
  governor = new Governor cfg
  compute = new ComputeTimer

  #console.log governor.config

  events = JSON.parse(fs.readFileSync(eventFile))
  console.log "got #{events.length} events\n"

  # XXX: have to combine all events at a given timestamp, to give queue data for everything at once
  # if history was done per role instead of globally, this would not be neccesary
  queueData = queueDataFromEvents cfg, events

  for d in queueData
    try
      s = governor.nextState null, d.queues
      compute.addState s, d.timestamps, d.workers # TODO: keep timestamp state internally?
    catch e
      console.log d.queues, s?, e
      console.log governor.history
      console.log e.stack

  types = {}
  for role, val of cfg
    types[role] = val.dynosize
#  console.log 'dyno sizes', types

#  console.log 'compute seconds', compute.accumulated
  costs = calculateCosts compute.accumulated, types
#  console.log 'costs', costs
  total = 0
  for role, v of costs
    console.log "#{role}: #{v.toFixed()} USD"
    total += v
  console.log "Total: #{total.toFixed()} USD"

main() if not module.parent
