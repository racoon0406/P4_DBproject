#!/bin/bash
# test2: tests additional put and get requests with versioning and edge cases
#        also test load balancing and failure detection behavior (PING/PONG)

# put values into database
./send.py put 10 100
./send.py put 10 101
./send.py put 10 102
./send.py put 10 103
./send.py put 10 104
./send.py put 10 105
./send.py put 11 110
./send.py put 11 111
./send.py put 11 112
./send.py put 12 120
./send.py put 12 121
./send.py put 12 122

./send.py put 512 51200
./send.py put 512 51201
./send.py put 512 51202
./send.py put 513 51300
./send.py put 513 51301
./send.py put 513 51302

# put key that already has 6 versions in database
./send.py put 10 106
./send.py put 10 107

# get value that exists
./send.py get 10 0
./send.py get 10 1
./send.py get 10 2
./send.py get 10 3
./send.py get 10 4
./send.py get 10 5
./send.py get 11 0
./send.py get 11 1
./send.py get 11 2
./send.py get 12 0
./send.py get 12 1
./send.py get 12 2
./send.py get 512 0
./send.py get 512 1
./send.py get 512 2
./send.py get 513 0
./send.py get 513 1
./send.py get 513 2

# get version out of bound or does not exist
./send.py get 10 6
./send.py get 10 10

# get version does not exist
./send.py get 11 3
./send.py get 12 4
./send.py get 512 5

# get value does not exist
./send.py get 13 0
./send.py get 14 0
./send.py get 25 0
./send.py get 514 0