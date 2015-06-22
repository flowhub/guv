

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

  return chart

# http://bl.ocks.org/phil-pedruco/88cb8a51cdce45f13c7e
normalChart = (data) ->
  margin =
    top: 20
    right: 20
    bottom: 30
    left: 50
  width = 960 - margin.left - margin.right
  height = 500 - margin.top - margin.bottom

  x = d3.scale.linear()
    .range([0, width])

  y = d3.scale.linear()
    .range([height, 0])

  x.domain(d3.extent(data, (d) -> return d.q ))
  y.domain(d3.extent(data, (d) -> return d.p ))

  xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")

  yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")

  line = d3.svg.line()
    .x( (d) -> return x(d.q) )
    .y( (d) -> return y(d.p) )

  svg = d3.select("body").append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

  svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + height + ")")
    .call(xAxis)

  svg.append("g")
    .attr("class", "y axis")
    .call(yAxis)

  svg.append("path")
    .datum(data)
    .attr("class", "line")
    .attr("d", line)

# from http://bl.ocks.org/mbostock/4349187
normal = () ->
  x = 0
  y = 0
  rds = null
  c = null

  doWhile = (func, condition) ->
    func()
    func() while condition()
    
  doWhile () ->
    x = Math.random() * 2 - 1
    y = Math.random() * 2 - 1
    rds = x * x + y * y
  , () ->
    return (rds == 0 || rds > 1)

  c = Math.sqrt(-2 * Math.log(rds) / rds) # Box-Muller transform
  return x * c # throw away extra sample y * c

# taken from Jason Davies science library
# https://github.com/jasondavies/science.js/
gaussian = (x) ->
  gaussianConstant = 1/Math.sqrt(2 * Math.PI)
  mean = 0
  sigma = 1

  x = (x - mean) / sigma
  return gaussianConstant * Math.exp(-.5 * x * x) / sigma


gaussianTestData = () ->
  data = []
  # loop to populate data array with probabily - quantile pairs
  for i in [0...100]
    q = normal()
    p = gaussian q
    el = { q: q, p: p }
    data.push el

  data.sort (x, y) ->
    return x.q - y.q


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

  gauss = gaussianTestData()
  normalChart gauss

  console.log 'main DONE'

main()
