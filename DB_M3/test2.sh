#!/bin/bash
# test2: tests range and select requests with versioning and 
#        ACL behavior for clients with different key range access

#          read      write
# Alice  [0, 1024]  [0, 512]
# Bob    [0, 256]   [0, 256]

# Alice range

# keys in [0, 4] second version
./send_Alice.py range 0 4 1

# keys in [0, 30] first version
./send_Alice.py range 1 30 0

# keys in [512, 513] first version
./send_Alice.py range 512 513 0

# keys in [1022, 1024] first version
./send_Alice.py range 1022 1024 0


# Alice select

# >
./send_Alice.py select gt 1022 0

# >=
./send_Alice.py select gteq 1022 0

# <
./send_Alice.py select ls 22 0
./send_Alice.py select ls 22 1

# <=
./send_Alice.py select lseq 22 0
./send_Alice.py select lseq 22 1

# ==
./send_Alice.py select eq 512 1
./send_Alice.py select eq 513 0
./send_Alice.py select eq 1024 0


# Bob range

# keys in [0, 4] second version
./send_Bob.py range 0 4 1

# keys in [0, 30] first version
./send_Bob.py range 1 30 0

# keys in [255, 258] first version
./send_Bob.py range 255 258 0     # Bob has no read access for [257, 258]

# keys in [1022, 1024] first version
./send_Bob.py range 1022 1024 0   # Bob has no read access


# Bob select

./send_Bob.py select gt 1022 0    # Bob has no read access

# >=
./send_Bob.py select gteq 1022 0  # Bob has no read access

# <
./send_Bob.py select ls 22 0
./send_Bob.py select ls 22 1

# <=
./send_Bob.py select lseq 22 0
./send_Bob.py select lseq 22 1

# ==
./send_Bob.py select eq 257 0     # Bob has no read access
./send_Bob.py select eq 258 0     # Bob has no read access
./send_Bob.py select eq 255 0
./send_Bob.py select eq 256 0
./send_Bob.py select eq 256 1