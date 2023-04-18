#!/bin/bash
# test3: tests range requests with versioning 
#        and select requests with versioning and different predicates
#        also tests load balancing and failure detection behavior (PING/PONG)

# range
# keys in [1,4] first version
./send.py range 1 4 0

# keys in [10, 15] third version
./send.py range 10 15 2

# select
# >
./send.py select gt 1022 0

# >=
./send.py select gteq 1022 0

# <
./send.py select ls 12 0
./send.py select ls 12 1

# <=
./send.py select lseq 12 0
./send.py select lseq 12 1

# ==
./send.py select eq 512 1
./send.py select eq 513 2