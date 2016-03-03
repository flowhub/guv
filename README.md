guv
===

`guv`, aka Grid Utilization Vigilante, is a governor for your (Heroku) workers:
It automatically scales the numbers of workers based on number of pending jobs in a (RabbitMQ) queue.

> Variable loads? Don't know how many servers you need? Woken up just to start more servers?
> Let robots do the tedious work for you!

The number of workers is calculated to attempt that all jobs are completed within a specified *deadline* (in seconds),
that you decide as your desired quality-of-service for your users.
The scaling is based on estimates of the job processing time (mean, variance), which you can calculate from metrics.

guv is written in Node.js, but can be used with workers in any programming language.

[Origin of the word guv](http://english.stackexchange.com/questions/14370/what-is-the-origin-of-the-british-guv-is-it-still-used-colloquially).

## License

guv is free and open source software under the [MIT license](./LICENSE.md)

## Status

*In production*

* Supports [RabbitMQ](https://www.rabbitmq.com/) messaging system and [Heroku](https://heroku.com/) workers
* Uses simple proportional algorithm for scaling to maintain a quality-of-service deadline
* Optional metric reporting to [statuspage.io](http://statuspage.io/) and [New Relic](http://newrelic.com)
* Used in production at [The Grid](https://thegrid.io) since June 2015
(with [MsgFlo](https://github.com/msgflo/msgflo))

## Usage

Install as NPM dependency

    npm install --save guv
    
Add it to your Procfile

    echo "guv: node node_modules/.bin/guv" >> Procfile

Configure an Heroku API key to use. Get it 

    heroku config:set HEROKU_API_KEY=`heroku auth:token`

Configure RabbitMQ instance to use. It must have the management plugin installed and configured.

    heroku config:set GUV_BROKER=amqp://[user:pass]@example.net/instance

Note: If you use CloudAMQP, guv will automatically respect the `CLOUDAMQP_URL` envvar. No config needed.

For guv own configuration we also recommend using an envvar.
This allows you to change the configuration without redeploying.
See below for details on the configuration format.

    heroku config:set GUV_CONFIG="`cat autoscale.guv.yaml`"

To verify that guv is running and working, check its log.

    heroku logs --app myapp --ps guv


## Configuration

The configuration format for guv is based specified in [YAML](http://yaml.org/).
Since it is a superset of JSON, you can also use that.

One guv instance can handle multiple worker *roles*.
Each role has an associated queue, worker and scaling configuration - specified as variables.

    # comment
    myrole:
      variable1: value1
    otherrole:
      variable2: value2

The special role name `*` is used for global, application-wide settings.
Each of the individual roles will inherit this configuration if they do not override it.

    # Heroku app is my-heroku-app, defaults to using a minimum of 5 workers, maximum of 50
    '*': {min: 5, max: 50, app: my-heroku-app}
    # uses only defaults
    imageprocessing: {}
    # except for text processing
    textprocessing:
      max: 10

Different `app` keys per role is supported, for services spanning multiple Heroku apps.

guv attempts to scale workers to be within a `deadline`, based on estimates of `processing` time.
To let it do a good job you should always specify the deadline, and *mean* processing time.

    # times are in seconds
    textprocessing:
      deadline: 100
      processing: 30

You can also specify the variance, as 1 standard deviation

    # 68% of jobs complete within +- 3 seconds
    textprocessing:
      deadline: 100
      processing: 30
      stddev: 3

The name of the `worker` and `queue` defaults to the `role name`, but can be overridden.

    # will use worker=colorextract and queue=colorextract
    colorextract: {}
    # explicitly specifying
    histogram:
      queue: 'hist.INPUT'
      worker: processhistograms

For list of all supported configuration variables see [./src/config.coffee](./src/config.coffee).
Many of the commonly used ones have short and long-form names.

guv configuration files by convention use the extension *.guv.yaml*, for instance `autoscale.guv.yaml` or `myproject.guv.yaml`.

# Metrics support

## New Relic

guv can report errors, and metrics about how workers are being scaled to [New Relic](https://newrelic.com/) Insights.

To enable, [setup a newrelic.js configuration](https://docs.newrelic.com/docs/agents/nodejs-agent/installation-configuration/nodejs-agent-configuration)
in the application that runs guv.

guv will one events of type `GuvScaled` per configured role, with payload:

      role: 'workerA'    # guv role this event is for
      app: 'imgflo'      # Heroku app name
      jobs: 142          # current jobs in queue
      workers: 7         # new value for number of workers

## Statuspage.io

guv can report metrics about in-flight jobs to your [statuspage.io](http://statuspage.io/).
See [status.thegrid.io](http://status.thegrid.io) for an example.

Set the API key as an environment variable

    export STATUSPAGE_API_TOKEN=mytoken

And configure in your guv.yaml file:

    '*':
      statuspage: 'my-statuspage-id'
    workerA:
      metric: 'my-statuspage-metric'


# Scaling model

![System model of scaling](./doc/system-model.png)

# Best practices

How to make the most out of guv.

### Measure the actual processing times of your jobs
Calculate mean and standard deviations, and use these in the `guv` config. You can use the
tool `guv-update-jobstats` to update your configuration, given a set of measurements of processing time.
For instance, if you use MsgFlo and NewRelic, you can use
[msgflo-jobstats-newrelic](https://github.com/msgflo/msgflo/blob/master/src/utils/newrelic.coffee) to
extract these numbers.

### Measure the actual end-to-end completion time for your jobs
When seen from a user perspective, so it includes the time the job was queued
(which is what guv tries to optimize). Monitor that they meet your target deadlines,
and identify the load cases where they do not.
Can be done by a 'started' timestamp when creating the job messages,
a 'stopped' timestamp when completed.

### Keep boot times of your workers as low as possible
Responsiveness to variable loads, especially sudden peaks is severely affected by boot time.
Avoid doing expensive computations, lots of I/O or waiting for external services during boot.
If neccesary do more during app build time, like creating caches or single-file builds.

To measure boot times, you can use the `guv-heroku-workerstats` tool.

### Separate out jobs with different processing time characterstics to different worker roles
If your job processing time has several clear peaks instead of one in the processing time histogram,
determine what the different cases are and use dedicated worker roles.
If your job processing time depends on the size of the job payload, implement an estimation
algorithm and route jobs into N different queues depending on which bin they fall into.

### Separate out jobs with different deadlines to different workers
Maintenance work, and anything else not required to maintain responsiveness for users,
should be done in separate queues, usually with a higher deadline.
This ensures that such background work does not disrupt quality-of-service.

### Use only one primary input queue per worker
The worker role (or 'dyno' in Heroku parlance) is the unit being scaled.
So if one worker role consumes from multiple queues, one has to chose which one of these should 'drive' the scaling.
Load caused on the other queue will influence this, but will not be taken into account.

If a single input queue is problematic, split up into multiple worker roles.
Or if the CPU/disk/network usage of processing of one queue is affecting processing of another queue too much.

There are currently no plans to consider multiple queues per role/worker when scaling.

### Jobs should be small
The more *independent* jobs work can be split into, the more parallizable the load will be,
and the lower the acheivable latency will be.
However if the job is extremely small, the message-passing overhead may start to become significant.

As a rough guideline, job processing should ideally be on the order of 1-10 seconds.

### Process jobs concurrently
AMQP allows specifying `prefetch`, which is how many messages (jobs) a consumer accepts at the same time.
This can help ensure that the CPU core(s) of the worker are fully saturated.

For loads which have significant time spend on I/O this can increase efficiency at lot.
Communicating with external network services, or reading/writing files from disk.

For a mixed CPU/IO-bound load a prefetch of around `2*cpucores` is a good baseline.
For primarily networked IO, try `10*cpucores`.
Make sure to specify `concurrency` in your guv config, and that the workers have enough memory.

