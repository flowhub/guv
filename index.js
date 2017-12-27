require('coffee-script/register');

module.exports = {
  main: require('./src/main'),
  config: require('./src/config'),
  scale: require('./src/scale'),
  validate: require('./src/validate'),
  updateconfig: require('./src/updateconfig'),
  heroku: require('./src/heroku'),
  governor: require('./src/governor'),
  insights: require('./src/insights'),
  statuspage: require('./src/statuspage')
};
