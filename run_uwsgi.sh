#!/bin/bash
cd /var/www/prism && uwsgi -s /dev/shm/prism.sock --module api --callable app -p 8 --stats :8252 --reload-on-as 150 --reload-on-exception --max-requests 10000 --uid $1 --pidfile2 /tmp/prism.pid
