#!/bin/bash

# test1: tests put and get requests with versioning and 
#        ACL behavior for clients with different key range access

#          read      write
# Alice  [0, 1024]  [0, 512]
# Bob    [0, 256]   [0, 256]

# Alice can write
./send_Alice.py put 1 10
./send_Alice.py put 1 11
./send_Alice.py put 1 12
./send_Alice.py put 2 20
./send_Alice.py put 2 21
./send_Alice.py put 3 30
./send_Alice.py put 4 40
./send_Alice.py put 512 51200
./send_Alice.py put 512 51201

# Alice cannot write
./send_Alice.py put 513 51300
./send_Alice.py put 1022 102200
./send_Alice.py put 1023 102300
./send_Alice.py put 1024 102400

# Bob can write
./send_Bob.py put 20 200
./send_Bob.py put 20 201
./send_Bob.py put 21 210
./send_Bob.py put 22 220
./send_Bob.py put 30 300
./send_Bob.py put 255 25500
./send_Bob.py put 256 25600
./send_Bob.py put 256 25601

# Bob cannot write
./send_Bob.py put 257 25700
./send_Bob.py put 258 25800
./send_Bob.py put 1000 100000
./send_Bob.py put 1001 100100

# Alice can read
./send_Alice.py get 1 0
./send_Alice.py get 1 1
./send_Alice.py get 1 2
./send_Alice.py get 2 0
./send_Alice.py get 2 1
./send_Alice.py get 3 0
./send_Alice.py get 4 0
./send_Alice.py get 20 0
./send_Alice.py get 20 1
./send_Alice.py get 21 0
./send_Alice.py get 22 0
./send_Alice.py get 256 0
./send_Alice.py get 512 0
./send_Alice.py get 512 1
./send_Alice.py get 513 0
./send_Alice.py get 1024 0

# Bob can read
./send_Bob.py get 1 0
./send_Bob.py get 1 1
./send_Bob.py get 1 2
./send_Bob.py get 4 0
./send_Bob.py get 256 0

# Bob cannot read
./send_Bob.py get 257 0
./send_Bob.py get 512 0
./send_Bob.py get 513 0
./send_Bob.py get 1024 0