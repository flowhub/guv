
Requirements

- Scale workers based on queue length
- Support _multiple_ workers/queues
- Failure to hit deadline when maxing out scale raises OPS error
- Store input metrics, settings and decisions somewhere - for analysis
- (optional) Scale webs workers based on request/response metrics
- (optional) Allow to run as a periodic job instead of dedicated dyno
- (optional) Visualization of results

- Notify failure on New Relic
- Monitor queues in RabbitMQ
- Scale dynos on Heroku

Non-requirements

- Scaling non-compute resources (databases etc)


Best practices

- Minimize worker boot time. More effective auto-scaling and robustness against spikes
- Measure the statistics of your job processing time. Get mean and variance as right as you can
- Put jobs with different processing times into reparate worker roles. GUV assumes normal distribution with single mean
- Monitor actual job processing time end-to-end, compare with deadline. Flag instances where failing to meet QoS


Settings

Should be able to have per-app defaults for each setting,
and then override per role. Also a global default ofc.

    minimum_dynos: . Should allow 0 (N dynos, Integer)
    maximum_dynos: Based on a budget. Also to catch cases where scaling goes crazy. (N dynos, Integer)
    target_deadline: The response time we shall attempt to keep. (seconds)
        
Things to consider

    hysteresis. avoiding scaling up/down unecessarily

    window length. how much history to consider
    rescale activation time. how long it takes to make a change (order of 1 minute)

    time spent in queue
    time spent performing job

Test cases

    Periodic fluctuations (sine wave)
    Within-target spike
    Out-of-bounds spike

Architecture

- Metric collectors: Gathers metrics about the apps
- Converters: Convers metrics into resource
- Actuators: Activates new number of resources
- Notificators: 

Prior art

- Dynosaur. Ruby gem. Dedicated dyno.
http://engineering.harrys.com/2014/01/02/dynosaur-a-heroku-autoscaler.html

- Workless. Ruby gem.
http://symmetricinfinity.com/2013/04/19/autoscale-workers-on-heroku-with-workless.html

- Viki. Ruby script. Cronjob.
https://github.com/viki-org/heroku-autoscale/blob/master/autoscale
http://engineering.viki.com/blog/2011/autoscaling-heroku-dynos/

- Python. Schedule-based scaling.
https://realpython.com/blog/python/automatically-scale-heroku-dynos/

- Adept Scale. Service, Heroku addon.
https://addons.heroku.com/adept-scale

- Heroku Vector. Ruby,Linear scaling.
https://github.com/wpeterson/heroku-vector

References

- https://devcenter.heroku.com/articles/scheduled-jobs-custom-clock-processes

