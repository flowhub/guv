#     guv - Scaling governor of cloud workers
#     (c) 2015 The Grid
#     guv may be freely distributed under the MIT license

async = require 'async'

# @func: function(key, value, cb). cb: function(err, returnvalue)
exports.mapDictionaryAsync = (obj, func, callback) ->
  f = (key, cb) ->
    value = obj[key]
    func key, value, (err, returnvalue) ->
      return callback err, { key: key, returnvalue: returnvalue }

  keys = Object.keys obj
  async.map keys, f, (err, results) ->
    return callback err if err
    objresults = {}
    for item in results
      objresults[item.key] = item.returnvalue
    return callback err, objresults

# returns true if predicate() is true for all items in sequence, else false
exports.all = (sequence, predicate) ->
  for i in [0...sequence.length]
    p = predicate sequence[i]
    return false if not p
  return true
