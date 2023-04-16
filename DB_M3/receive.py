#!/usr/bin/env python3
import os
import sys

from scapy.all import (
    IP,
    TCP,
    Ether,
    FieldLenField,
    FieldListField,
    IntField,
    IPOption,
    ShortField,
    get_if_list,
    sniff
)
from scapy.layers.inet import _IPOption_HDR
from query_h import Query, MultiVal, PingPong, Access

client_list = {0: "Alice", 1: "Bob"}

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface

class IPOption_MRI(IPOption):
    name = "MRI"
    option = 31
    fields_desc = [ _IPOption_HDR,
                    FieldLenField("length", None, fmt="B",
                                  length_of="swids",
                                  adjust=lambda pkt,l:l+4),
                    ShortField("count", 0),
                    FieldListField("swids",
                                   [],
                                   IntField("", 0),
                                   length_from=lambda pkt:pkt.count*4) ]
def handle_pkt(pkt):  
    global client_list
    #Spkt.show2() 
    if PingPong in pkt and pkt[PingPong].type == 2: #PONG
        print("received a PONG from switch " + str(pkt[Query].responder))
    elif Query in pkt and pkt[Query].responder == 0:
        if pkt[Access].no_read_access == 1:
            print("Error!!! Client " + client_list[pkt[Access].clientID] + " has no access to read the key(s)")
        if pkt[Access].no_write_access == 1:
            print("Error!!! Client " + client_list[pkt[Access].clientID] + " has no access to write the key")
    elif Query in pkt and pkt[Query].responder != 0:        
        #print("got a query packet")
        #pkt.show2()
        if pkt[PingPong].s1_dead == 1:
            print("switch 1 is dead")
            return
        if pkt[PingPong].s2_dead == 1:
            print("switch 2 is dead")
            return
        #print("received REQUEST value(s) from " + str(pkt[Query].responder))
        print("[Client " + client_list[pkt[Access].clientID] + "]", end=": ")
        if pkt[Query].queryType == 0: #get
            print("get value from switch " + str(pkt[Query].responder))
            if pkt[MultiVal].has_val == 0:
                print("NULL")
            else:
                print(pkt[MultiVal].value)
        elif pkt[Query].queryType == 1: #put
            print("try to put(key= " + str(pkt[Query].key1) + ", value= " + str(pkt[Query].value) + ") to switch " + str(pkt[Query].responder))
        elif pkt[Query].queryType == 2: #range, select
            print("get multiple values from switch " + str(pkt[Query].responder))
            index = 0
            result = list()
            while(True):
                layer = pkt.getlayer(index)
                if layer == None:
                    break
                index += 1
                if layer.name == "MultiVal":
                    if layer.has_val == 1:
                        result.append(layer.value)
                    else:
                        result.append("NULL")
            if len(result) > 0 :
                result.pop()
            print(result)  
        sys.stdout.flush()
    


def main():
    ifaces = [i for i in os.listdir('/sys/class/net/') if 'eth' in i]
    iface = ifaces[0]
    print("sniffing on %s" % iface)
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
