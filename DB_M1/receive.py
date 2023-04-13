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
from query_h import Query, MultiVal

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
    if Query in pkt and pkt[Ether].dst != 'ff:ff:ff:ff:ff:ff':        
        #print("got a query packet")
        #pkt.show2()
        if pkt[Query].queryType == 0: #get
            if pkt[MultiVal].has_val == 0:
                print("NULL")
            else:
                print(pkt[MultiVal].value)
        elif pkt[Query].queryType == 1: #put
            print("try to put(key= " + str(pkt[Query].key1) + ", value= " + str(pkt[Query].value) + ")")
        elif pkt[Query].queryType == 2: #range, select
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
