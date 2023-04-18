# Milestone 2
For this milestone, we have implemented key/value store partitions, load balancing, and fault tolerance in a four-switch system:  
- s0: frontend load balancing switch
- s1: key/value store partition switch for keys in [0, 512]
- s2: key/value store partition switch for keys in (513, 1024]  
- s3: standby switch for keys in [0, 1024]

## Main Files Created

### P4 Programs
- `DB_M2_s0.p4`
- `DB_M2_s1.p4`
- `DB_M2_s2.p4`
- `DB_M2_s3.p4`

### Python Scripts
- `query_h.py`
- `send.py`
- `receive.py`

### Configuration Files
- `topology.json`
- `s0-runtime.json`
- `s1-runtime.json`
- `s2-runtime.json`
- `s3-runtime.json`

### Test scripts
- `run_tests.sh`: Test runner that runs all tests below
- `test1.sh`: Tests simple PUT and GET requests without versioning, while also evaluating load balancing and failure detection (PING/PONG) behavior
- `test2.sh`: Tests versioned PUT and GET requests with edge cases, as well as load balancing and failure detection (PING/PONG) behavior
- `test3.sh`: Tests versioned RANGE requests, versioned SELECT requests with diverse predicates, load balancing, and failure detection (PING/PONG) behavior

## Run Test Script
1. In a shell with the required VM image installed, navigate to `/DB_M2` directory and run:
    ```bash
    make
    ```
2. Open a terminal for **h1** in the mininet environment: 
    ```bash
    xterm h1
    ```
3. In the terminal for **h1**, make sure to give the test runner executable permission by running:
    ```bash
    chmod +x run_tests.sh
    ```
4. Run tests:
    ```bash
    ./run_tests.sh
    ```
   It will execute all tests `test*.sh` and prints out a summary in the end.   

5. Type `exit` to leave each xterm and the mininet environment. Then, to stop mininet:  
    ```bash
    make stop
    ```
   To delete all `.pcap` files, build files, and logs:  
    ```bash
    make clean
    ```

## Run Manually
1. In a shell with the required VM image installed, navigate to `/DB_M2` directory and run:
    ```bash
    make
    ```
2. Open terminals for sender and receiver in the mininet environment:
    ```bash
    xterm h1 h1
    ```

3. In one terminal of **h1**, start the receiver by running:
    ```bash
    ./receive.py
    ```

4. In the other terminal of **h1**, you can issue PUT, GET, RANGE, or SELECT queries as sender.   
   Issue a GET request:
    ```bash
    ./send.py get <key> <version> 
    ```
   Issue a PUT request:
    ```bash
    ./send.py put <key> <value> 
    ```
   Issue a RANGE request:
    ```bash
    ./send.py range <key1> <key2> <version> 
    ```
   Issue a SELECT request:
    ```bash
    ./send.py select <operand> <value> <version>
    ```
   Valid `<operand>` options are: `gt`, `gteq`, `ls`, `lseq`, `eq`, corresponding to >, >=, <, <=, ==  

   For example: `./send.py select lseq 5 0` will send a SELECT request for `key <= 5` and version number `0`, 
    and only the first version key/value pairs with keys less than or equal to 5 will be returned on receiver side  
    
5. Type `exit` to leave each xterm and the mininet environment. Then, to stop mininet:  
    ```bash
    make stop
    ```
   To delete all `.pcap` files, build files, and logs:  
    ```bash
    make clean
    ```