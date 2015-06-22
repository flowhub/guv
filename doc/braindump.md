
## Tools TODO

- Timing Heroku dyno boot time
- Calculating mean, stddev from processing time stats. Output as config
- Test whether processing times are normally distributed.
Visual+[analytical test](https://en.wikipedia.org/wiki/Normality_test).
- Calculate clusters/bins to separate multi-mode, non-normal data into
- A runnable+introspectable model of the scaling algorithm. Ability to test it on real/historical data.
- For a given configuration, estimate what loads can (and cannot) be handled

## Smarter scaling

Right now, guv uses the simplest (stupidest) model that can possibly work:
Scale the number of workers proportionally to messages in the queue.
Scaling factor is based on processing time estimates versus deadline.

This model is completely reactive, it only actuates changes after situation as occurred. No prediction.
The model does not take into account the (significant) time costs of dyno boot up.

Scaling function should receive all neccesary state.
The state collected could be a window of (jobs, workers) measurements.
Measurements must be timestamped, window should be time-based, number of measurements/time
as high as possible (without being disruptive). Cannot assume measurements will be evenly spaced.

Key questions:

- When considering to scale down,
what is the probability that we will go back up or above N messages (and thus W workers),
within the next 30-60 seconds.
- What is the cost of overestimating/overprovisioning


## Initial design

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

    Periodic fluctuations (sine wave, square, triangle)
    Within-target spike
    Out-of-bounds spike

Architecture

- Metric collectors: Gathers metrics about the apps
- Converters: Convers metrics into resource
- Actuators: Activates new number of resources
- Notificators: 

## Prior art

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

## References

- https://devcenter.heroku.com/articles/scheduled-jobs-custom-clock-processes
- https://en.wikipedia.org/?title=Queueing_theory
- http://stats.stackexchange.com/questions/18821/why-is-the-poisson-distribution-chosen-to-model-arrival-processes-in-queueing-th
- http://www.math.uah.edu/stat/poisson/Poisson.html
