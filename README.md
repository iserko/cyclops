![Cyclops is meant to be a high performance barrier in front of [sentry](http://getsentry.com)](/logo.png)

[![Build Status](https://travis-ci.org/heynemann/cyclops.png?branch=master)](https://travis-ci.org/heynemann/cyclops)

Disclaimer
==========

[sentry](http://getsentry.com) is an amazing tool and greatly improves the level of quality of projects using it, web or not.

Huge props to the whole team behind it and to @disqus for releasing it to the public as open source, thus allowing us to better understand how it works.

The Issue
=========

That said, if you have a large enough volume of requests (i.e.: > 5000 requests/second), a single Javascript error could bring your whole sentry farm down.

After some extensive Load Testing with sentry, it's just not viable to have sentry as the Front End to error reporting (considering the volume of requests above).

Cyclops aims at being able to handle tens of thousands of error reporting requests per second. Afterwards, Cyclops sends them to sentry in a rate that's calculated using sentry's own response time as basis.

Cyclops
=======

Cyclops is a router of sentry error reporting requests. It receives error reports, keeps them in-memory (or any other storage you implement) and sends to your sentry backend in regular intervals.

It takes into account the time your sentry backend is taking to service each request when calculating the interval with which to send the next request, thus making sure you don't flood your sentry backend.

In preliminary load testing, a server with 23 instances of Cyclops running handled more than 12 thousand requests per second.

Installing
==========

Installing Cyclops is as easy as:

    $ pip install cyclops

Usage
=====

Cyclops comes with a console app called 'cyclops' (pretty imaginative bunch, aren't we?).

    $ cyclops --help
    usage: cyclops [-h] [--port PORT] [--bind BIND] [--conf CONF] [--verbose]
                 [--debug]

    optional arguments:
      -h, --help            show this help message and exit
      --port PORT, -p PORT  Port to start the server with.
      --bind BIND, -b BIND  IP to bind the server to.
      --conf CONF, -c CONF  Path to configuration file.
      --verbose, -v         Log level: v=warning, vv=info, vvv=debug.
      --debug, -d           Indicates whether to run tornado in debug mode.

The arguments are self-explanatory. The key argument is the configuration file.

Configuration
=============

The configuration file is where you tell Cyclops how to behave, how to store data, how to connect to sentry, etc.

    ################################### General ####################################

    ## Cyclops has a /healthcheck route. This allows load balancers to ping it to see
    ## if the process is still alive. This option defines the text that the
    ## /healthcheck route prints.
    ## Defaults to: WORKING
    #HEALTHCHECK_TEXT = 'WORKING'

    ## Sentry server name. This is the base URL that Cyclops will use to send
    ## requests to sentry.
    ## Defaults to: localhost:9000
    #SENTRY_BASE_URL = 'localhost:9000'

    ## Cyclops keeps sentry's projects public and security keys in memory. This
    ## allows a very fast validation as to whether each request is valid. This
    ## configuration defines the interval in seconds that Cyclops will update the
    ## keys.
    ## Defaults to: 120
    #UPDATE_PERIOD = 120

    ## This configuration tells cyclops to process newly arrived error reports first.
    ## This is very useful to avoid that error bursts stop you from seeing new
    ## errors.
    ## Defaults to: True
    #PROCESS_NEWER_MESSAGES_FIRST = True

    ## The storage class used in Cyclops. Storage classes are what define how
    ## received requests will be treated *before* sending to sentry. Built-ins:
    ## "cyclops.storage.InMemoryStorage" and "cyclops.storage.RedisStorage."
    ## Defaults to: cyclops.storage.InMemoryStorage
    #STORAGE = 'cyclops.storage.InMemoryStorage'

    ################################################################################


    ################################# Performance ##################################

    ## Cyclops will try to send the errors it receives to sentry as fast as possible.
    ## This is done using a percentile average of 90% of the last sentry requests
    ## time. If those requests were serviced in 30ms average, then cyclops will
    ## keep sending requests every 30ms. This setting specify a maximum interval
    ## in miliseconds to send requests to sentry.
    ## Defaults to: 1000
    #MAX_DUMP_INTERVAL = 1000

    ## In order to calculate the average requests, Cyclops keeps track of the times
    ## of the last requests sent to sentry. This setting specifies the maximum
    ## number of requests to average.
    ## Defaults to: 5000
    #MAX_REQUESTS_TO_AVERAGE = 5000

    ################################################################################


    ################################### Database ###################################

    ## Host of your sentry installation MySQL database.
    ## Defaults to: localhost
    #MYSQL_HOST = 'localhost'

    ## Port of your sentry installation MySQL database.
    ## Defaults to: 3306
    #MYSQL_PORT = 3306

    ## Database of your sentry installation MySQL database.
    ## Defaults to: sentry
    #MYSQL_DB = 'sentry'

    ## User of your sentry installation MySQL database.
    ## Defaults to: root
    #MYSQL_USER = 'root'

    ## Password of your sentry installation MySQL database.
    ## Defaults to:
    #MYSQL_PASS = ''

    ################################################################################


    #################################### Cache #####################################

    ## The amount of seconds to cache a given URL of error. This is meant to be a way
    ## to avoid flooding your sentry farm with repeated errors. Set to 0 if you
    ## don't want to cache any errors.
    ## Defaults to: 1
    #URL_CACHE_EXPIRATION = 1

    ## Number of requests to accept in the specified expiration of the cache per url.
    ## Defaults to: 10
    #MAX_CACHE_USES = 10

    ## The cache implementation to use to avoid sending the same error again to
    ## sentry.
    ## Defaults to: cyclops.cache.RedisCache
    #CACHE_IMPLEMENTATION_CLASS = 'cyclops.cache.RedisCache'

    ## The host where the Redis server is running. If you are not using redis, set
    ## this to None.
    ## Defaults to: 127.0.0.1
    #REDIS_HOST = '127.0.0.1'

    ## The port that Redis server is running.
    ## Defaults to: 7780
    #REDIS_PORT = 7780

    ## The number of redis db.
    ## Defaults to: 0
    #REDIS_DB_COUNT = 0

    ## The redis password
    ## Defaults to: None
    #REDIS_PASSWORD = None

    ################################################################################

The Routes
==========

Cyclops mymics the `api/store` routes in sentry. Both the `GET` and `POST` routes.

You can send the errors to Cyclops in *EXACTLY* the same way you would send to sentry.

There's one additional route, though: `/count`.

This route returns a JSON object that tells you how that specific Cyclops instance is doing (how many messages to process, average and percentile response time).

An example output of the `/count` route:

    {
        count: 0, // Messages to be sent to sentry
        average: 77.491357729, // Average response time for sentry requests
        percentile: 72.9767654253, // 90% Percentil of response time for sentry requests
        processed: 10, // Number of processed sentry errors for this cyclops process
        ignored: 300 // Number of ignored sentry errors for this cyclops process
    }


Storage
=======

Cyclops allows users to specify any storage mechanism they want for storing messages before sending them to sentry. It comes bundled with in-memory and redis storages, but it's pretty simple to implement a new storage class, say for MemCached.

A storage class has to implement the following interface:

    def __init__(self, application):
        # stores application for further usage
        # and does any initialization needed

    def put(self, project_id, message):
        # stores the message for later processing for the given project

    def get_size(self, project_id):
        # returns the size of the "queue" for a given project

    def get_next_message(self):
        # gets the next message to process, independent of project
        # usually this is done in a round-robin fashion among projects

    def mark_as_done(self, project_id):
        # indicates to the "queue" that this message is done processing
        # which means it has been sent to sentry

    @property
    def total_size(self):
        # returns the total size of all project queues

    @property
    def available_queues(self):
        # returns a list of project ids


Caching
=======

Besides allowing users to store messages wherever they want, Cyclops allows for extensible cache implementations as well.

Caching in Cyclops is a little different than what you might be used to. It is used as a mechanism for dropping messages that might flood your sentry farm.

Consider what would happen if you had a page that gets hit 1000 times each second and you introduce a javascript error in it. You would get millions of VERY similar messages flooding your farm by the time you got to fix it.

Cyclops uses the caching implementation to prevent that. If it detects that the given key (for GET requests it's the URL, for POST requests it's the Project Id + Culprit) has been processed more than `MAX_CACHE_USES` in the last `URL_CACHE_EXPIRATION` seconds it will discard it.

Consider an expiration of 1 second with 10 max cache uses. This means that if the same key arrives more than 10 times each second, the 11th, 12th and so on will be discarded. After the second ellapses, the cache key is discarded and we start processing messages again.

It might seem weird to process only 1% of the error requests (1000 reqs/sec and we process 10/sec), but most likely that 1% should be enough info to allow you to fix the problem.

Implementing a Custom Cache is very simple, even though Cyclops comes bundled with a very efficient Redis cache implementation. Your cache needs to conform to this interface:

    def __init__(self, application):
        # stores application for further usage
        # and does any initialization needed

    def get(self, key):
        # gets a key usages.
        # should return an integer if key is found, None otherwise

    def incr(self, key):
        # should increment the number of times a key has been used by 1

    def set(self, key, expiration):
        # should set a key to 0 and set it's expiration to "expiration" seconds


cyclops-count
=============

Using the `/count` route, we can keep track of the performance of individual Cyclops instances and of the load of each of them. It would be a tedious task to track the load and performance of each instance, though.

Cyclops comes with a helper program that allows you to specify a server and a range of ports representing Cyclops instances, like this:

    $ cyclops-count -b http://localhost -p 9000-9004

This command would return output similar to:

    localhost:9000 has still 10 messages to process
    localhost:9001 has still 10 messages to process
    localhost:9002 has still 10 messages to process
    localhost:9003 has still 10 messages to process
    localhost:9004 has still 10 messages to process

    Total of 50 messages to send to [sentry](http://getsentry.com) from the farm at localhost.

    Total 300 processed items and 3000 ignored items (10.00%).
    Average sentry response time is 2918.66ms and 90% Percentile is 2339.53ms

This way you can keep track of how your farm is doing *A LOT* easier.

Hosting
=======

Hosting cyclops is as easy as hosting a tornado application.
This is a disclaimer that the way showcased here is NOT the only way to do it.

In this scenario we assume [supervisor](http://supervisord.org/) to monitor tornado instances. 
It will starts 10 instances of Cyclops in ports ranging from 9100 to 9109.

In order to load balance requests to those 10 instances, NGinx is used.

Supervisor config sample
------------------------

    [program:cyclops]
    command=cyclops -p 91%(process_num)02d -c /path/conf.file
    process_name=cyclops%(process_num)02d
    user=nobody
    numprocs=10
    autostart=true
    autorestart=true
    startretries=3
    stopsignal=TERM
    stdout_logfile=/var/log/cyclops/cyclops.stdout.%(process_num)02d.log
    stdout_logfile_maxbytes=100MB
    stdout_logfile_backups=10
    stderr_logfile=/var/log/cyclops/cyclops.stderr.%(process_num)02d.log
    stderr_logfile_maxbytes=100MB
    stderr_logfile_backups=10

NGINX config sample
-------------------

    http {
        proxy_ignore_headers Expires Cache-Control;
        proxy_intercept_errors on;
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504 http_404;
        proxy_pass_header X-Forwarded-For;
        proxy_pass_header X-Real-IP;

        error_page 400 401 403 404 405  /errordocument/404.html;
        error_page 500 502 503 504      /errordocument/500.html;

        upstream gateway {
            server 0.0.0.0:9100;
            server 0.0.0.0:9101;
            server 0.0.0.0:9102;
            server 0.0.0.0:9103;
            server 0.0.0.0:9104;
            server 0.0.0.0:9105;
            server 0.0.0.0:9106;
            server 0.0.0.0:9107;
            server 0.0.0.0:9108;
            server 0.0.0.0:9109;
        }
        server {
            server_name cyclops.com;

            listen  my_ip:8080 _;

            location ~ ^/login/$ {
                return 404;
            }

            location ~ /api/([\w_-]+/)?store {
                proxy_pass http://gateway;
            }

            location /count {
                proxy_pass http://gateway;
            }

            location / {
                return 404;
            }

        }
    }

If you have anything to add to these configuration files (in order to improve the way everyone hosts cyclops),
please create an issue and we'll be more than happy to update the docs.

Contributing
============

If you wish to contribute to Cyclops, file and issue or send us a pull request.

License
=======

Cyclops is licensed under the MIT License:

The MIT License

Copyright (c) 2013 Bernardo Heynemann heynemann@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.