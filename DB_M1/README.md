# Milestone 1
For this milestone, we have implemented in-network key/value store in a single P4 programmable switch s0. It supports GET, PUT, RANGE, and SELECT requests. 

## Main Files Created

### P4 Programs
- `DB_M1.p4`

### Python Scripts
- `query_h.py`
- `send.py`
- `receive.py`

### Configuration Files
- `topology.json`
- `s1-runtime.json`

### Test Scripts
- TODO


## Run Test Scripts
TODO

## Run Manually
1. In a shell with the required VM image installed, navigate to `/DB_M1` directory and run:
    ```bash
    make
    ```
2. Open terminals for sender and receiver in the mininet environment 
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
