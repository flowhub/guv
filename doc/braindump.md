
## Tools TODO

- Timing Heroku dyno boot time
- Test whether processing times are normally distributed.
Visual+[analytical test](https://en.wikipedia.org/wiki/Normality_test).
- Calculate clusters/bins to separate multi-mode, non-normal data into
- A runnable+introspectable model of the scaling algorithm. Ability to test it on real/historical data.
- For a given configuration, estimate what loads can (and cannot) be handled

## Simulation

Discrete-event simulation

* [Introduction to Discrete-Event Simulation and the SimPy Language](http://heather.cs.ucdavis.edu/~matloff/156/PLN/DESimIntro.pdf)
* [An introduction to Discrete-Event Simulation](https://www.cs.cmu.edu/~music/cmsip/readings/intro-discrete-event-sim.html),
pedagocical introduction of concepts and possible ways to implement.
* [Sim.js](https://github.com/btelles/simjs-updated), JavaScript library for discrete-event simulation. Updated in 2016, but not much used.

### Aspects

#### Input process
Part of app / execution environment.
Type of distribution. Poisson, uniform
Distribution parameters
Low-load conditions
High-load conditions
Periodic changes
Gradual changes, abrupt changes

#### Job processing
Each assumed to be mostly independent.
However not entirely true. Sharing CPU resources, sharing RAM, sharing disk I/O, network I/O,
at least with other jobs in same worker. Possibly also with other workers, and
even other workers from other apps co-hosted on the same hardware/hypervisor.

#### Worker
Part of app.

Actions: Scale up, scale down. Complete new message.
Spawn time (Cloud service side), startup time (app side).
Shutdown time (app side)

Prefetch setting

Worker crash (and restart)
Worker crashed state (not restarting)
Worker deadlocked. Not accepting new messages

#### Broker service (RabbitMQ)

Interfaces:
HTTP GET for Autoscaling communication
AMQP broker for worker/app communication.

Broker crash/restart
Broker not accepting messages. Quota full etc.
Timeout getting queue info
Unexpected error getting queue info

#### Cloud service (Heroku)

Interface: HTTP GET/POST

Exceeding max workers
Permission denied. Wrong credentials etc
Unexpected error.

#### Autoscaling service (guv)

Role configuration
Scaling algorithm


### General considerations

Many of the aspects considered apply to MsgFlo, without autoscaling.
Also in other systems, like IoT using MQTT/Mosquitto.

Need a componenent models. Using NoFlo.js would be nice for that.
Would be nice to use FBP graphs for setting up network.
But if event-driven the evaluation model does not match, events need
to be executed based on the time the new event is for.

All cross-service comunication goes over network.
There is a non-trivial amount of latency, and a non-zero error rate.
The simulation should be able to model this, including bad and error-conditions.

### Use for end-to-end testing

If simulation can talk the regular protocols, it can be used to run the real service against in end-to-end tests.
Such tests likely need less simulation fidelity, and run with simulation speed == real-time.
But possibly using some data recorded from the past, either from simulation or real system.
Such data can probably be re-dated. 

In end-to-end, should probably mostly be using a standard AMQP broker.
The ability to simulate AMQP broker makes it possible.

## Queueing theory
https://en.wikipedia.org/wiki/Queueing_theory

> The average delay any given packet is likely to experience is given by the formula 1/(μ-λ)
> where μ is the number of packets per second the facility can sustain
> and λ is the average rate at which packets are arriving to be serviced
https://en.wikipedia.org/wiki/Queuing_delay (networking theory)

> The long-term average number of customers in a stable system L is equal to
> the long-term average effective arrival rate, λ, multiplied by the (Palm‑)average time a customer spends in the system, W;
> or expressed algebraically: L = λW
> 
> "not influenced by the arrival process distribution, the service distribution, the service order, or practically anything else"
https://en.wikipedia.org/wiki/Little%27s_law


[The General Distributional Little's Law and its Applications](https://dspace.mit.edu/bitstream/handle/1721.1/2348/SWP-3277-23661119.pdf)

> `M/M/c queue` in Kendall's notation it describes a system where arrivals form a single queue
> and are governed by a Poisson process,
> there are c servers and job service times are *exponentially distributed*.
https://en.wikipedia.org/wiki/M/M/c_queue

Can we model job processing times with an [exponential distribution](https://en.wikipedia.org/wiki/Exponential_distribution)?
Means executing at less than median is more probable than executing at more.
Maybe if job processing time is dependent on payload (linear or above linear), and large payloads are rare compared to small.
This *might* be the case for instance for images.

> M/G/k queue is a queue model where arrivals are Markovian (modulated by a Poisson process),
> service times have a General distribution and thereare k servers
> Most performance metrics for this queueing system are not known and remain an open problem.
https://en.wikipedia.org/wiki/M/G/k_queue

Assuming a Poisson-distributed in model, and a normal distributed processing time model,
this is the category that guv currently ends up in.

An approximation that has been proposed, is to use the coefficient of variation of the service time distribution (C)
as a correcting factor on the solution for the M/M/c case. Known as 

[Approximations for the GI/G/m Queue](http://www.columbia.edu/~ww2040/ApproxGIGm1993.pdf) (Whitt, AT&T Bell Labs, 1993).
Section 2 covers Expected Waiting Time (EWT). Also considered are estimates for queue length (EQ),
number of active servers (EB), number of customers in the system (EN), total time including processing (ET).
There exists exact relations between all of these numbers (Equations 2.2),
so it suffices to find one of the variables to obtain an estimate for the others. 
Equation (2.14) proposes an heavy-traffic estimate for EW for GI/G/m based on the known EW(M/M/m), corrected using .
A special-case with cA^2=1 can also give a known heavy-traffic estimate for M/G/m.
It states that "however, improvements can be made considering light-traffic limits), citing a number of papers.
Equation 2.24 is the proposed "New" algorithm, applying pieces of existing known estimates or exact solutions.
This is shown to work well, with exact match to EB, very accurate EN, and fairly accurate+robust EW.

This method is similar in basic principle (using variance to correct) to what guv currently does, but much more rigorous. 


> The Poisson point process is often defined on the real line, where it can be considered as a stochastic process.
> In this setting, it is used, for example, in queueing theory to model random events,
> such as the arrival of customers at a store or phone calls at an exchange, distributed in time
https://en.wikipedia.org/wiki/Poisson_point_process

Any process has two key properties: follows a Poisson distribution, and there is complete independence between events.
Two sub-categories exist. Homogenous/stationary, which has one constant parameter λ, the rate/intensity.
λ can be interpreted as the average number of points per some unit of extent (ex: time). Can be called mean rate / mean density.
For an inhomogenous/nonhomogenous process, the Poisson parameter is a *location dependent function of the space*.

> A feature of the one-dimension setting, is that an inhomogeneous Poisson process can be transformed into a homogeneous
> by a monotone transformation or mapping, which is achieved with the inverse of Λ

> The inhomogeneous Poisson point process, when considered on the positive half-line, is also sometimes defined as a counting process.
> A counting process is said to be an inhomogeneous Poisson counting process if it has the four properties...
This has a special-case, simplified, solution

How to simulate a Poisson point process: https://en.wikipedia.org/wiki/Poisson_point_process#Simulation


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

- pedro/delayed_job. Fork of Delayed::Job Ruby gem with autoscaling support. Only supports on/off with 0/1 workers.
https://github.com/pedro/delayed_job/tree/autoscaling#autoscaling-with-heroku

## References

- https://devcenter.heroku.com/articles/scheduled-jobs-custom-clock-processes
- https://en.wikipedia.org/?title=Queueing_theory
- http://stats.stackexchange.com/questions/18821/why-is-the-poisson-distribution-chosen-to-model-arrival-processes-in-queueing-th
- http://www.math.uah.edu/stat/poisson/Poisson.html
