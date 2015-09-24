
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

