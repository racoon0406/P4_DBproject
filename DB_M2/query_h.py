import sys

from scapy.all import (
    IP, TCP, Ether, 
    Packet, bind_layers, BitField, IntField, ShortField
    )

TYPE_IPV4 = 0x0800
TYPE_QUERY = 0x0801
TYPE_MULTIVAL = 0x0802
TYPE_PINGPONG = 0x0803

class PingPong(Packet):
    name = "PingPong"
    fields_desc=[ 
        BitField("isPong", 0, 1),
        BitField("padding", 0, 7),
        IntField("queryCount", 0),   
    ]

class Query(Packet):
    name = "Query"
    fields_desc=[ 
                BitField("queryType", 0, 2),
                BitField("isFeedback", 0, 1),
                #Order matters: while dissecting key 1, can only concatenate tuple (not bytes) to tuple
                BitField("padding", 0, 5),
                IntField("key1", 0),    	
                IntField("key2", 0),
                IntField("value", 0),    	
                IntField("version", 0),
                IntField("count", 1),    
                ShortField("protocol", TYPE_MULTIVAL)
                ]

class MultiVal(Packet):
    name = "MultiVal"
    fields_desc=[ 
                IntField("value", 0),
                BitField("has_val", 0, 1),
                BitField("has_next", 0, 1),
                BitField("padding", 0, 6)]


bind_layers(Ether, PingPong, type = TYPE_PINGPONG)
#When Scapy encounters an Ethernet type=0x0801, it will parse the next layer as "Query" header
bind_layers(Ether, Query, type = TYPE_QUERY)
bind_layers(Query, MultiVal, protocol = TYPE_MULTIVAL)
bind_layers(MultiVal, IP, has_next = 0)
bind_layers(MultiVal, MultiVal, has_next = 1)