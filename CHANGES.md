
# guv 0.1.9

Released: Feburary 2, 2016.

* Take `concurrency` into account when scaling. New per-role configuration key.
For workers with AMQP `prefetch` setting / concurrency>1 , we were overestimating the number of required workers.
We assumed that each new job would add processing time P to the waiting time, instead of P/concurrency amortized.

# guv 0.1.7

Released: December 18, 2015.

* Fix hysteresis to go down gradually, instead of requiring history window to be below current
Could cause a high number of workers to sustain when they were no longer need,
in cases periods of fluctuating low demand after very high demand.

# guv 0.1.5

Released: December 18, 2015.

* Added tool `guv-newrelic-events`, to download. Can be used to analyze guv performance.
* Fix bug #59, was scaling to minimum instead of maximum on unrealizable config
* guv-validate: Error on configurations which are impossible to realize

# guv 0.1.3

* Added tool `guv-update-jobstats`, to automate updating processing/stddev estimates in config file.
If you use MsgFlo with New Relic, you can get the input data using `msgflo-jobstats-newrelic`.

# guv 0.1.2

* Implemented hysteresis, take history into account when scaling.
* Fix bug #8, failing to scale everything if some queues missing

# guv 0.1.0

Released: November 25, 2015.

* First public release. [Blogpost announcement](http://www.jonnor.com/2015/11/guv-automatic-scaling/).
