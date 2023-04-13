/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//constants defined, 16 bits(like short)
const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_QUERY = 0x0801;
const bit<16> TYPE_MULTIVAL = 0x0802;
const bit<16> TYPE_PINGPONG = 0x0803;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
//define alias for bit<n>
typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

//define a register persistent through all packets
//s1: stores keys in [0, 512]
register<bit<32> >(1025 * 6) db_value; //version# is limited [0,5]
register<bit<32> >(1025) lastest_version; 
register<bit<1> >(1025) key_exist; //0: not exist

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
    bit<1>   s1_dead; //0: alive
    bit<1>   s2_dead; 
    //BMv2 target only supports headers with fields totaling a multiple of 8 bits.
    bit<3>   padding;
    bit<32>  responder; //s1,s2,s3
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

    //PUT request has (key1, value)
    action put() {
        key_exist.read(meta.key_exist, hdr.query.key1);
        lastest_version.read(meta.version, hdr.query.key1);
        db_value.read(meta.value, hdr.query.key1 * 6 + meta.version);
        //key not exists, add (key1, value)
        if(meta.key_exist == 0)
        {
            //meta.version is 0
            meta.value = hdr.query.value;
        }
        else // key exists, add a new version of (key1, value)
        {
            if(meta.version < 5)
            {
                meta.version = meta.version + 1;
                meta.value = hdr.query.value;
            }                    
        } 
        key_exist.write(hdr.query.key1, 1);
        lastest_version.write(hdr.query.key1, meta.version);
        db_value.write(hdr.query.key1 * 6 + meta.version, meta.value);        
        }
    

    //GET request has (key1, version)
    action get() {
        key_exist.read(meta.key_exist, hdr.query.key1);
        lastest_version.read(meta.version, hdr.query.key1);
        //get value and store in header  
        db_value.read(hdr.multiVal[0].value, hdr.query.key1 * 6 + hdr.query.version);
        if(meta.key_exist == 1 && hdr.query.version <= meta.version)
        {
            hdr.multiVal[0].has_val = 1;       
        }      
    }

    //RANGE request has (key1, key2, version)
    action range_get() {     
        //shift header stack by 1, which invalidate the first element 
        hdr.multiVal.push_front(1);
        hdr.multiVal[0].setValid();  
        hdr.multiVal[0].has_next = 1;        
        key_exist.read(meta.key_exist, hdr.query.key1);
        lastest_version.read(meta.version, hdr.query.key1);
        //get value and store in header
        db_value.read(hdr.multiVal[0].value, hdr.query.key1 * 6 + hdr.query.version);
        if(meta.key_exist == 1 && hdr.query.version <= meta.version)
        {
            hdr.multiVal[0].has_val = 1;           
        }               
        if(hdr.query.key1 < hdr.query.key2)
        {           
            hdr.query.count = hdr.query.count + 1; 
        }
    }

    action set_nhop(egressSpec_t port) {
        //decide which port of current switch to go to
        standard_metadata.egress_spec = port;
        //decrement ttl
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    //when incoming packet passes this table, it has diff actions based on its dstAddr
    table ipv4_lpm {
        key = {
            //longest prefix match
            hdr.ipv4.dstAddr: lpm;
        }
        //switch case based on key
        actions = {
            drop;
            set_nhop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    table operation {
        key = {
            hdr.query.queryType: exact;
        }
        //switch case based on key
        actions = {
            drop;
            get; //0
            put; //1
            range_get;  //2     
            //select; //3, unused
            NoAction;
        }
        size = 4;
        default_action = NoAction();
    }

    //ingress logic starts here
    apply {
        if(hdr.ipv4.isValid() && hdr.ipv4.ttl > 0){
            if(hdr.pingPong.type == 0) //this is a normal REQUEST
            {
                hdr.query.isFeedback = 1;
                operation.apply();  
            }  
            else //PING
            {
                //modify to PONG
                hdr.pingPong.type = 2;
            }   
            //respond from switch 2   
            hdr.query.responder = 2;   
            ipv4_lpm.apply();                 
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
        //'resubmit' can only be invoked in egress recirculate_preserving_field_list
        //loop to get next key value for RANGE and SELECT
        if(hdr.pingPong.type == 0 && hdr.query.queryType >= 2 && hdr.query.key1 < hdr.query.key2)
        {
            //update the key for next loop
            hdr.query.key1 = hdr.query.key1 + 1; 
            recirculate_preserving_field_list(0);
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
