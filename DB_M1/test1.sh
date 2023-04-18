#!/bin/bash
# test1: tests simple put and get requests without versioning

# put values into database
./send.py put 1 10
./send.py put 2 20
./send.py put 3 30
./send.py put 4 40

./send.py put 1022 102200
./send.py put 1023 102300
./send.py put 1024 102400


# get values from database
./send.py get 1022 0
./send.py get 1023 0
./send.py get 1024 0

./send.py get 1 0
./send.py get 2 0
./send.py get 3 0
./send.py get 4 0