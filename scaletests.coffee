
guv = require './'

## Take a JSON with list of scenarios and output the state after scaling 
# Each scenario has: config,role,history,workers,messages

runScenario = (test) ->  
  cfg = guv.config.load test.config

  role = test.role or '*'
  history = test.history or []
  currentWorkers = test.workers or null
  messages = test.messages

  state = guv.scale.scaleWithHistory cfg[role], role, history, currentWorkers, messages
  scaled = state.next

  return scaled

collectStdin = (callback) ->
  data = ""

  process.stdin.on 'data', (chunk) ->
    data += chunk.toString()
  process.stdin.on 'end', () ->
    return callback null, data

main = () ->
  callback = (err, results) ->
    if err
      console.error err
      return process.exit 2
    console.log(JSON.stringify(results, null, 2))

  collectStdin (err, data) ->
    return callback err if err
    try
      scenarios = JSON.parse(data)
      results = scenarios.map(runScenario)
    catch e
      return callback e
    return callback null, results

main() if not module.parent
