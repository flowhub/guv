
# guv = require 'guv'

# DOM helpers
dom =
  id: (name) ->
    document.getElementById name

# UI React widgets      
class TestStatusClass
  render: () ->
    total = countCases @props.suites, () -> return true
    passing = countCases @props.suites, (c) -> return c.passed? and c.passed
    failing = countCases @props.suites, (c) -> return c.passed? and not c.passed
    skipped = countCases @props.suites, (c, s) -> return c.skip? or s.skip?
    # TODO: also consider pending
    # TODO: visualize running / not-running
    # FIXME: visualize overall pass/fail
    (ul {className: 'test-status'}, [
      (li {className: 'pass'}, passing)
      (li {className: 'fail'}, failing)
      (li {className: 'skip'}, skipped)
      (li {}, total)
    ])

TestStatus = React.createFactory TestStatusClass


# UI: d3.js stuffs
lineChart = (datum) ->
  # Setup
  chart = nv.models.lineChart()
                .margin({left: 100})
                .useInteractiveGuideline(true)
                .showLegend(true)
                .showYAxis(true)
                .showXAxis(true)

  chart = nv.models.lineWithFocusChart()

  series = datum[3]
  console.log series?, typeof series, Object.keys series
  max_Y = d3.max series.values, (item) -> item.y
  chart.yDomain([0, max_Y*1.15])

  chart.xAxis
      .axisLabel('Time (s)')
      .tickFormat(d3.format(',r'))

  chart.yAxis
      .axisLabel('Requests rate (req/s)')
      .tickFormat(d3.format('.02f'))

  # Update the chart when window resizes.
  nv.utils.windowResize chart.update

  return chart;

# get data
dataSeries = (params) ->

  data =
    base: []
    weekly: []
    daily: []
    total: []
  timePeriod = 60*60*24*30
  samples = 1000
  samplesPerSecond = timePeriod / samples
  computeSample = (i) ->
    seconds = samplesPerSecond*i
    base = params.base
    w = params.weekly*Math.sin(2*Math.PI*(seconds/(7*24*60*60)))
    d = params.daily*Math.sin(2*Math.PI*(seconds/(1*24*60*60)))
    total = base+w+d

    total = 0.0 if total < 0.0

    data.base.push { x: seconds, y: base }
    data.weekly.push { x: seconds, y: w+base }
    data.daily.push { x: seconds, y: d+base }
    data.total.push { x: seconds, y: total }
  indices = (num for num in [0..samples])
  indices.forEach computeSample

  return [
      values: data.base,
      key: 'Baseline',
      color: '#ff7f0e'
    ,
      values: data.weekly,
      key: 'Weekly variation',
      color: '#2ca02c'
    ,
      values: data.daily
      key: 'Daily variation'
      color: '#7777ff'
    ,
      values: data.total
      key: 'Total'
      color: '#ff00ff'
      area: true
  ]


# Main
main = () ->
  console.log 'main'

  selector = '#chart svg'

  render = (data) ->
    nv.addGraph () ->
      graph = lineChart data
      d3.select(selector)
          .datum(data) 
          .call(graph)
      return graph

  inputs = ["weekly", "daily", "base"]
  onChange = () ->
    console.log 'onchange'
    params = {}
    for id in inputs
      params[id] = parseFloat(dom.id(id).value)
    data = dataSeries params
    render data

  for id in inputs
    dom.id(id).oninput = onChange
  onChange()

  console.log 'main DONE'

main()
