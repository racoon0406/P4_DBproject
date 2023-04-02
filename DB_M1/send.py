#!/usr/bin/env python3
import random
import socket
import sys
import argparse
from random import choice
from string import ascii_uppercase

from scapy.all import (
    IP, TCP, Ether, get_if_hwaddr, get_if_list, sendp
    )
from query_h import Query, MultiVal

def get_if():
    ifs=get_if_list()
    iface=None # "h1-eth0"
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface

def get(key_in, version_in):
    if key_in > 1024 or key_in < 0:
        print("key should be between 0 and 1024")
        exit(1)
    if version_in > 5 or version_in < 0:
        print("version should be between 0 and 5")
        exit(1)
    query_text = "get(key=" + str(key_in) + ", version=" + str(version_in) + ")"
    print(query_text)
    #print("sending on interface %s to %s" % (iface, str(addr)))
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff', type=TYPE_QUERY)
    pkt = pkt / Query(queryType=0, key1=key_in, version=version_in) / MultiVal() / IP(dst=addr) / TCP(dport=1234, sport=random.randint(49152,65535)) / query_text
    #pkt.show2()
    sendp(pkt, iface=iface, verbose=False)

def put(key_in, value_in):
    if key_in > 1024 or key_in < 0:
        print("key should be between 0 and 1024")
        exit(1)
    query_text = "put(key=" + str(key_in) + ", value=" + str(value_in) + ")"
    print(query_text)
    #print("sending on interface %s to %s" % (iface, str(addr)))
    pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff', type=TYPE_QUERY)
    pkt = pkt / Query(queryType=1, key1=key_in, value=value_in) / MultiVal() / IP(dst=addr) / TCP(dport=1234, sport=random.randint(49152,65535)) / query_text
    #pkt.show2()
    sendp(pkt, iface=iface, verbose=False)

def range(key1_in, key2_in, version_in):
    if key1_in > 1024 or key1_in < 0 or key2_in > 1024 or key2_in < 0:
        print("keys should be between 0 and 1024")
        exit(1)
    if key1_in > key2_in:
        print("key1 should be smaller than or equal to key2")
        exit(1)
    if version_in > 5 or version_in < 0:
        print("version should be between 0 and 5")
        exit(1)
    print("range(key1=" + str(key1_in) + ", key2=" + str(key2_in) + ", version=" + str(version_in) + ")")
    for cur_key1 in range(key1_in, key2_in + 1, 10):
        cur_key2 = min(key1_in + 9, key2_in)
        query_text = "split range(key1=" + str(cur_key1) + ", key2=" + str(cur_key2) + ", version=" + str(version_in) + ")"
        #print("sending on interface %s to %s" % (iface, str(addr)))
        pkt =  Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff', type=TYPE_QUERY)
        pkt = pkt / Query(queryType=2, key1=cur_key1, key2=cur_key2, version=version_in) / MultiVal() / IP(dst=addr) / TCP(dport=1234, sport=random.randint(49152,65535)) / query_text
        #pkt.show2()
        sendp(pkt, iface=iface, verbose=False)

def main():
    if len(sys.argv) < 2:
        print("Begin from enter: <operation>, Option: get, put, range, select")
        exit(1)

    addr = "10.0.1.1"
    iface = get_if()

    if(sys.argv[1] == "get"):
        if len(sys.argv) < 4:
            print("Enter: get <key> <version>")
        get(int(sys.argv[2]), int(sys.argv[3]))        
    elif(sys.argv[1] == "put"):
        if len(sys.argv) < 4:
            print("Enter: put <key> <value>")
        put(int(sys.argv[2]), int(sys.argv[3]))   
    elif(sys.argv[1] == "range"):
        if len(sys.argv) < 5:
            print("Enter: range <key1> <key2> <version>")
        range(int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]))   
    elif(sys.argv[1] == "select"):
        if len(sys.argv) < 4:
            print("Enter: select <predicate> <pre_val> <version>")
        predicate = sys.argv[1]
        pre_val = int(sys.argv[2])
        version_in = int(sys.argv[3])
        final_key1 = 0
        final_key2 = 1024
        print("select(key " + predicate + " " + str(pre_val) + ", version=" + str(version_in) + ")")
        if predicate == "==":
            get(val_in, version_in)
        elif predicate == ">":
            final_key1 = val_in + 1          
        elif predicate == ">=":
            final_key1 = val_in
        elif predicate == "<":
            final_key2 = val_in - 1
        elif predicate == "<=":
            final_key2 = val_in 
        else
            print("Invalid predicate type, Option: ==, >, >=, <, <=")
            exit(1)
        range(final_key1, final_key2, version_in)      
    else:
        print("Invalid operation type, Option: get, put, range, select")
        exit(1)

if __name__ == '__main__':
    main()
