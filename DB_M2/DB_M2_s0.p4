/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//define constants for packet type
#define PKT_INSTANCE_TYPE_INGRESS_CLONE 1
#define FAILURE_BOUND 5

//constants defined, 16 bits(like short)
const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_QUERY = 0x0801;
const bit<16> TYPE_MULTIVAL = 0x0802;
const bit<16> TYPE_PINGPONG = 0x0803;

const bit<32> REPORT_MIRROR_SESSION_ID = 500;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
//define alias for bit<n>
typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

//define a register persistent through all packets
//0: # of total requests
//1: # of ping to s1, 3: # of pong from s1
//2: # of ping to s2, 4: # of pong from s2
register<bit<32> >(5) request_tracker; 



//headers defined
//ethernet is usually the first header, all important
//length should not be changed(protocol)
header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header pingPong_t {
    bit<2>   type; //0: normal packet, 1: PING, 2: PONG
    bit<6>   padding; 
}

/*
 * This is a custom protocol header for the query packet. We'll use
 * ethertype 0x0801 for is (see parser)
 */
header query_t {
    bit<2>   queryType; //4 types of requests
    bit<1>   isFeedback; //1: is feedback
    bit<1>   s1_dead; //0: alive, 1: switch1 is dead
    bit<1>   s2_dead; 
    //BMv2 target only supports headers with fields totaling a multiple of 8 bits.
    bit<3>   padding;
    bit<32>  responder; //who returns the packet: s1,s2,s3
    bit<32>  key1;
    bit<32>  key2;
    bit<32>  value;
    bit<32>  version;
    bit<32>  count;
    bit<16>  protocol;   
}

//For SELECT and RANGE, the result may have multiple values
header multiVal_t {
    bit<32>  value; 
    bit<1>   has_val; //0: no value   
    bit<1>   has_next; //0: this is the last multiVal header  
    bit<6>   padding; 
}
 
header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl; //important, time to live
    bit<8>    protocol; //important
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr; //important
    ip4Addr_t dstAddr; //important
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

//local variable, whose life span is a single packet
struct metadata {
    @field_list(0)
    //to read if key exists or not
    bit<1> key_exist;
    //to read version#
    bit<32> version;
    //to read value
    bit<32> value;
    //load balancing
    bit<16> ecmp_select;
    //to read request_tracker
    bit<32> num_request;
    bit<32> num_ping_s1;
    bit<32> num_pong_s1;
    bit<32> num_ping_s2;
    bit<32> num_pong_s2;

    bit<1> clone_ping; //flag, indicating we need 2 clones to send PING
    bit<1> clone_standby ; //flag, indicating we need 1 clone to send to stand-by switch
}

//header stack, add all the headers you plan to use
struct headers {
    ethernet_t   ethernet;
    pingPong_t   pingPong;
    query_t      query;
    multiVal_t[1025]   multiVal; //header stack
    ipv4_t       ipv4;
    tcp_t        tcp;   
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
//parser logic
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    
    state start {
        /* TODO: add parser logic */
        transition parse_ethernet; //always transfer to parse_ethernet state
    }

    state parse_ethernet{
	//try to parse and match the format of ethernet header
        packet.extract(hdr.ethernet);
        //switch case
        transition select(hdr.ethernet.etherType) //get next header type(e.g. ipv4, ipv6)
        {
            TYPE_PINGPONG: parse_pingPong;
            default: accept;
        }
    }

    state parse_pingPong{
        packet.extract(hdr.pingPong);
        transition parse_query;
    }

    state parse_query{
        packet.extract(hdr.query);
        transition select(hdr.query.protocol) {
            TYPE_MULTIVAL: parse_multiVal;
            default: accept;
        }
     }

     state parse_multiVal{
        packet.extract(hdr.multiVal.next);
        transition select(hdr.multiVal.last.has_next) {
            0: parse_ipv4; //this is the last multiVal header
            1: parse_multiVal; //continue to parse next multiVal
            default: accept; 
        }
     }

    //only when packet passes this state(triggered extract), ipv4 header becomes valid
    state parse_ipv4{
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
     }

     state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/
//pass
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action set_ecmp_select() {
        request_tracker.read(meta.num_request, 0);
        request_tracker.read(meta.num_ping_s1, 1);
        request_tracker.read(meta.num_ping_s2, 2);
        request_tracker.read(meta.num_pong_s1, 3);
        request_tracker.read(meta.num_pong_s2, 4);

        if(hdr.query.isFeedback == 1) //feedback packet
        {
            meta.ecmp_select = 1;
        } 
        else if(hdr.pingPong.type == 2) //PONG packet
        {
            //update statistics
            meta.num_pong_s1 = meta.num_pong_s1 + 1;
            meta.num_pong_s2 = meta.num_pong_s2 + 1;

            meta.ecmp_select = 1;
        }
        else //request packet
        {
            //for every 10th request s0 receives
            //P4 not support modulo...
            //if(meta.num_request % 10 == 9)
            if((meta.num_request & 0b1111) == 0b1001)
            {
                //flag, clone later
                meta.clone_ping = 1;
                //update statistics
                meta.num_ping_s1 = meta.num_ping_s1 + 1;
                meta.num_ping_s2 = meta.num_ping_s2 + 1;
            }
            //else if(meta.num_request % 15 == 14)
            else if(((meta.num_request & 0b1111) == 0b1110) 
            && (((meta.num_request >> 4) & 0b111) == 0b111))
            {
                //check the number of PING and PONG
                if(meta.num_ping_s1 - meta.num_pong_s1 > FAILURE_BOUND)
                {
                    hdr.query.s1_dead = 1;
                }
                if(meta.num_ping_s2 - meta.num_pong_s2 > FAILURE_BOUND)
                {
                    hdr.query.s2_dead = 1;
                }
            }

            if(hdr.query.key1 <= 512) //key1 [0,512]
            {
                meta.ecmp_select = 2;
            }
            else //key1 (512,1024]
            {
                meta.ecmp_select = 3;
            }

            if(hdr.query.queryType == 1) //PUT 
            {
                //flag, clone later
                meta.clone_standby = 1;
            }
            //update statistics
            meta.num_request = meta.num_request + 1;
        }
        //write back to tracker
        request_tracker.write(0, meta.num_request);
        request_tracker.write(1, meta.num_ping_s1);
        request_tracker.write(2, meta.num_ping_s2);
        request_tracker.write(3, meta.num_pong_s1);
        request_tracker.write(4, meta.num_pong_s2);
    }

    action set_nhop(egressSpec_t port) {
        //decide which port of current switch to go to
        standard_metadata.egress_spec = port;
        //decrement ttl
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    //when incoming packet passes this table, it has diff actions based on its dstAddr
    table ecmp_nhop {
        key = {
            meta.ecmp_select: exact;
        }
        actions = {
            drop;
            set_nhop;
        }
        size = 5; //be careful!!
    }

    //when incoming packet passes this table, it has diff actions based on its dstAddr
    table ecmp_group {
        key = {
            //longest prefix match
            hdr.ipv4.dstAddr: lpm;
        }
        //switch case based on key
        actions = {
            drop;
            set_ecmp_select;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    //ingress logic starts here
    apply {
        if(hdr.ipv4.isValid() && hdr.ipv4.ttl > 0){   
            ecmp_group.apply();   
            ecmp_nhop.apply();   
            if(meta.clone_ping == 1)
            {
                //clone by session 2, will send clones(PING) to s1, s2
                clone(CloneType.I2E, 2);  
            }
            if(meta.clone_standby == 1)
            {
                //clone by session 1, will send to s3(stand-by switch)
                clone(CloneType.I2E, 1);
            }
                      
        }
    }
}


/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
//pass
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { 
        if (standard_metadata.instance_type == PKT_INSTANCE_TYPE_INGRESS_CLONE
            && standard_metadata.egress_spec != 4) {
            //modify the clone packet into PING packet, not work as normal REQUEST packet
            hdr.pingPong.type = 1;
        }
     }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/
//pass
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/
//reassemble our packet
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        //order matters
        packet.emit(hdr.ethernet);
        packet.emit(hdr.pingPong);
        packet.emit(hdr.query);
        packet.emit(hdr.multiVal);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
