# Milestone 3
For this milestone, we have implemented the storage with access control list (ACL) mechanism on the frontend switch s0, 
with the assumption that there are only two clients, Alice and Bob, with IDs `0` and `1`.  s0 is responsible for verifying 
whether a client ID has access to a particular key range.  

The key range access for Alice and Bob is detailed below:  

|       | Read Access | Write Access |
|:-----:|:-----------:|:------------:|
| Alice |  [0, 1024]  |   [0, 512]   |
|  Bob  |   [0, 256]  |   [0, 256]   |

## Main Files Created

### P4 Programs
- `DB_M3_s0.p4`
- `DB_M3_s1.p4`
- `DB_M3_s2.p4`
- `DB_M3_s3.p4`

### Python Scripts
- `query_h.py`
- `send_Alice.py`
- `send_Bob.py`
- `receive.py`

### Configuration Files
- `topology.json`
- `s0-runtime.json`
- `s1-runtime.json`
- `s2-runtime.json`
- `s3-runtime.json`

### Test Scripts and Output Files
- `run_tests.sh`: Test runner that runs all tests below
- `test1.sh`: Tests versioned PUT and GET requests with ACL, focusing on clients with different levels of key range read/write access
- `test2.sh`: Tests versioned RANGE request with ACL, and versioned SELECT requests with ACL and various predicates, focusing on clients with different levels of key range read/write access
- `expected/`: Directory that contains the expected output files, `test*.out`, for each respective test
- `output/`: Directory that stores the test outputs generated upon the completion of each test run

## Run Test Script
1. In a shell with the required VM image installed, navigate to `/DB_M3` directory and run:
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
1. In a shell with the required VM image installed, navigate to `/DB_M3` directory and run:
    ```bash
    make
    ```
2. Open terminals for sender and receivers in the mininet environment: 
    ```bash
    xterm h1 h1
    ```

3. In one terminal of **h1**, start the receiver by running:
    ```bash
    ./receive.py
    ```

4. In the other terminal of **h1**, Alice or Bob can issue PUT, GET, RANGE, or SELECT queries as sender.   
   Issue a GET request:
    ```bash
    ./send_<Alice/Bob>.py get <key> <version> 
    ```
   Issue a PUT request:
    ```bash
    ./send_<Alice/Bob>.py put <key> <value> 
    ```
   Issue a RANGE request:
    ```bash
    ./send_<Alice/Bob>.py range <key1> <key2> <version> 
    ```
   Issue a SELECT request:
    ```bash
    ./send_<Alice/Bob>.py select <operand> <value> <version>
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