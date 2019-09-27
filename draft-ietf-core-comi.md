---
stand_alone: true
ipr: trust200902
docname: draft-ietf-core-comi-08
cat: std
pi:
  toc: 'yes'
  symrefs: 'yes'
title: CoAP Management Interface
abbrev: CoMI
area: Applications
wg: CoRE
author:
- ins: M. V. Veillette
  role: editor
  name: Michel Veillette
  org: Trilliant Networks Inc.
  street: 610 Rue du Luxembourg
  city: Granby
  region: Quebec
  code: J2J 2V2
  country: Canada
  email: michel.veillette@trilliant.com
- ins: P. van der Stok
  role: editor
  name: Peter van der Stok
  org: consultant
  abbrev: consultant
  phone: "+31-492474673 (Netherlands), +33-966015248 (France)"
  email: consultancy@vanderstok.org
  uri: www.vanderstok.org
- ins: A. P. Pelov
  name: Alexander Pelov
  org: Acklio
  street: 2bis rue de la Chataigneraie
  city: Cesson-Sevigne
  region: Bretagne
  code: '35510'
  country: France
  email: a@ackl.io
- ins: A. Bierman
  name: Andy Bierman
  org: YumaWorks
  street:
  - 685 Cochran St.
  - 'Suite #160'
  city: Simi Valley
  region: CA
  code: '93065'
  code: '93065'
  country: USA
  email: andy@yumaworks.com
- role: editor
  ins: I. I. Petrov
  name: Ivaylo Petrov
  org: Acklio
  street: 1137A avenue des Champs Blancs
  code: '35510'
  city: Cesson-Sevigne
  region: Bretagne
  country: France
  email: ivaylo@ackl.io
normative:
  RFC2119:
  RFC8174:
  RFC4648:
  RFC5277:
  RFC6241:
  RFC6243:
  RFC7049:
  RFC7252:
  RFC7950:
  RFC7959:
  RFC7641:
  RFC8132:
  RFC8040:
  I-D.ietf-core-yang-cbor:
  I-D.ietf-core-sid:
  I-D.ietf-core-yang-library:
informative:
  RFC6347:
  RFC6690:
  RFC7223:
  RFC7317:
  RFC8342:
  RFC8613:

--- abstract

This document describes a network management interface for constrained devices
and networks, called CoAP Management Interface (CoMI). The Constrained Application
Protocol (CoAP) is used to access datastore and data node resources specified
in YANG, or SMIv2 converted to YANG. CoMI uses the YANG to CBOR mapping and converts
YANG identifier strings to numeric identifiers for payload size reduction.
The complete solution composed of CoMI, {{I-D.ietf-core-yang-cbor}} and
{{I-D.ietf-core-sid}} is called CORECONF. CORECONF extends the set of YANG based
protocols, NETCONF and RESTCONF, with the capability to manage constrained devices
and networks.

--- note_Note


Discussion and suggestions for improvement are requested,
and should be sent to yot@ietf.org.

--- middle

# Introduction {#introduction}

The Constrained Application Protocol (CoAP) {{RFC7252}} is designed for
Machine to Machine (M2M) applications such as smart energy, smart city and building control.
Constrained devices need to be managed in an automatic fashion to handle
the large quantities of devices that are expected in
future installations. Messages between devices need to be as small and
infrequent as possible. The implementation
complexity and runtime resources need to be as small as possible.

This draft describes the CoAP Management Interface which uses CoAP methods
to access structured data defined in YANG {{RFC7950}}. This draft is
complementary to {{RFC8040}} which describes a REST-like interface
called RESTCONF, which uses HTTP methods to access structured data
defined in YANG.

The use of standardized data models specified in a standardized language, such
as YANG, promotes interoperability between devices and applications from
different manufacturers.

CORECONF and RESTCONF are intended to work in a stateless client-server fashion.
They use a single round-trip to complete a single editing transaction, where
NETCONF needs multiple round trips.

To promote small messages, CORECONF uses a YANG to CBOR mapping
{{I-D.ietf-core-yang-cbor}} and numeric identifiers {{I-D.ietf-core-sid}}
to minimize CBOR payloads and URI length.

## Terminology {#terminology}

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 {{RFC2119}} {{RFC8174}}
when, and only when, they appear in all capitals, as shown here.

The following terms are defined in the YANG data modelling language {{RFC7950}}: action, anydata, anyxml, client, container, data model, data node, identity, instance identifier, leaf, leaf-list, list, module, RPC, schema node, server, submodule.

The following terms are defined in {{RFC6241}}: configuration data, datastore, state data

The following term is defined in {{I-D.ietf-core-sid}}: YANG schema item identifier (SID).

The following terms are defined in the CoAP protocol {{RFC7252}}: Confirmable Message, Content-Format, Endpoint.

The following terms are defined in this document:

data node resource:
: a CoAP resource that models a YANG data node.

datastore resource:
: a CoAP resource that models a YANG datastore.

event stream resource:
: a CoAP resource used by clients to observe YANG notifications.

notification instance:
: An instance of a schema node of type notification, specified in a YANG module
  implemented by the server. The instance is generated in the server at the occurrence
  of the corresponding event and reported by an event stream resource.

list instance identifier:
: Handle used to identify a YANG data node that is an instance of a YANG "list"
  specified with the values of the key leaves of the list.


single instance identifier:
: Handle used to identify a specific data node which can be instantiated only
  once. This includes data nodes defined at the root of a YANG module and
  data nodes defined within a container. This excludes data nodes defined
  within a list or any children of these data nodes.

instance-identifier:
: List instance identifier or single instance identifier.

instance-value:
: The value assigned to a data node instance. Instance-values are serialized into
  the payload according to the rules defined in section 4 of {{I-D.ietf-core-yang-cbor}}.


# CoMI Architecture {#comi-architecture}

This section describes the CoMI architecture to use CoAP for reading and
modifying the content of datastore(s) used for the management of the instrumented
node.


~~~~
+----------------------------------------------------------------+
|                SMIv2 specification (optional) (2)              |
+----------------------------------------------------------------+
                               |
                               V
+----------------------------------------------------------------+
|                     YANG specification  (1)                    |
+----------------------------------------------------------------+
         |                                            |
Client   V                               Server       V
+----------------+                       +-----------------------+
|        Request |--> CoAP request(3) -->| Indication            |
|        Confirm |<-- CoAP response(3)<--| Response          (4) |
|                |                       |                       |
|                |<==== Security (7) ===>|+---------------------+|
+----------------+                       || Datastore(s)    (5) ||
                                         |+---------------------+|
                                         |+---------------------+|
                                         || Event stream(s) (6) ||
                                         |+---------------------+|
                                         +-----------------------+
~~~~
{: #archit title='Abstract CoMI architecture' artwork-align="left"}

 {{archit}} is a high-level representation of the main elements of the CoMI management
architecture. The different numbered components of {{archit}} are discussed according to component number.


(1) YANG specification:
: contains a set of named and versioned modules.


(2) SMIv2 specification:
: Optional part that consists of a named module which, specifies a set of variables and "conceptual tables". There
  is an algorithm to translate SMIv2 specifications to YANG specifications.


(3) CoAP request/response messages:
: The CoMI client sends request messages to and receives response messages
  from the CoMI server.


(4) Request, Indication, Response, Confirm:
: Processes performed by the CoMI clients and servers.


(5) Datastore:
: A resource used to access configuration data, state data, RPCs and actions. A CoMI server may support a single unified datastore or multiple datastores as those defined by Network Management Datastore Architecture (NMDA) {{RFC8342}}.


(6) Event stream:
: A resource used to get real time notifications. A CoMI server may support multiple Event streams serving different purposes such as normal monitoring, diagnostic, syslog, security monitoring.


(7) Security:
: The server MUST prevent unauthorized users from reading or writing any CoMI
  resources. CoMI relies on security protocols such as DTLS {{RFC6347}} or OSCOAP {{RFC8613}} to secure CoAP communications.


## Major differences between RESTCONF and CORECONF {#major-differences}

CORECONF is a RESTful protocol for small devices where saving bytes to transport
counts. Contrary to RESTCONF, many design decisions are motivated by the
saving of bytes. Consequently, CORECONF is not a RESTCONF over CoAP protocol,
but differs more significantly from RESTCONF.

### Differences due to CoAP and its efficient usage {#major-differences-coap}

* CORECONF uses CoAP/UDP as transport protocol and CBOR as payload format
  {{I-D.ietf-core-yang-cbor}}. RESTCONF uses HTTP/TCP as transport
  protocol and JSON or XML as payload formats.

* CORECONF uses the methods FETCH and iPATCH to access multiple data nodes.
  RESTCONF uses instead the HTTP method PATCH and the HTTP method GET with the "fields" Query parameter.

* RESTCONF uses the HTTP methods HEAD, and OPTIONS, which are not supported by CoAP.

* CORECONF does not support "insert" query parameter (first, last, before, after)
  and the "point" query parameter which are supported by RESTCONF.

* CORECONF does not support the "start-time" and "stop-time" query parameters
  to retrieve past notifications.

### Differences due to the use of CBOR {#major-differences-cbor}

* CORECONF encodes YANG identifier strings as numbers, where RESTCONF does not.

* CORECONF also differ in the handling of default values, only 'report-all' and 'trim' options are supported.

## Compression of YANG identifiers {#id-compression}

In the YANG specification, items are identified with a name string. In order
to significantly reduce the size of identifiers used in CoMI, numeric
 identifiers called YANG Schema Item iDentifier (SID) are used instead.

When used in a URI, SIDs are encoded using base64 encoding of the SID bytes. The base64 encoding is using the URL and Filename safe
alphabet as defined by {{RFC4648}} section 5, without padding. The last 6 bits encoded is always aligned
with the least significant 6 bits of the SID represented using an unsigned integer.
'A' characters (value 0) at the start of the resulting string are removed. See {{Fig-sid-encoding}} for complete illustration.

~~~~
SID in base64 = URLsafeChar[SID >> 60 & 0x3F] |
                 URLsafeChar[SID >> 54 & 0x3F] |
                 URLsafeChar[SID >> 48 & 0x3F] |
                 URLsafeChar[SID >> 42 & 0x3F] |
                 URLsafeChar[SID >> 36 & 0x3F] |
                 URLsafeChar[SID >> 30 & 0x3F] |
                 URLsafeChar[SID >> 24 & 0x3F] |
                 URLsafeChar[SID >> 18 & 0x3F] |
                 URLsafeChar[SID >> 12 & 0x3F] |
                 URLsafeChar[SID >> 6 & 0x3F] |
                 URLsafeChar[SID & 0x3F]
~~~~
{: #Fig-sid-encoding artwork-align="left"}

For example, SID 1721 is encoded as follow.

~~~~
URLsafeChar[1721 >> 60 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 54 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 48 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 42 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 36 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 30 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 24 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 18 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 12 & 0x3F] = URLsafeChar[0] = 'A'
URLsafeChar[1721 >> 6 & 0x3F]  = URLsafeChar[26] = 'a'
URLsafeChar[1721 & 0x3F]       = URLsafeChar[57] = '5'
~~~~
{: artwork-align="left"}

The resulting base64 representation of SID 1721 is "a5"

## Instance-identifier {#instance-identifier}

Instance-identifiers are used to uniquely identify data node instances within a datastore. This YANG built-in type is defined in {{RFC7950}} section 9.13. An instance-identifier is composed of the data node identifier (i.e. a SID) and for data nodes within list(s) the keys used to index within these list(s).

When part of a payload, instance-identifiers are encoded in CBOR based on the rules defined in {{I-D.ietf-core-yang-cbor}} section 6.13.1. When part of a URI, the SID is appended to the URI of the targeted datastore, the keys are specified using the 'k' URI-Query as defined in {{query}}.


## Content-Formats {#content-format}

CoMI uses Content-Formats based on the YANG to CBOR mapping specified
in {{I-D.ietf-core-yang-cbor}}.

The following Content-formats are defined:

application/yang-data+cbor:

: This Content-Format represents a CBOR YANG document containing one or multiple data node values.
  Each data node is identified by its associated SID.


: FORMAT: CBOR map of SID, instance-value

: The message payload of Content-Format 'application/yang-data+cbor' is encoded using a CBOR map.
  Each entry within the CBOR map contains the data node identifier (i.e. SID) and the associated instance-value.
  Instance-values are encoded using the rules defined in {{I-D.ietf-core-yang-cbor}} section 4.

application/yang-identifiers+cbor:

: This Content-Format represents a CBOR YANG document containing a list of instance-identifier used to target specific data node instances within a datastore.

: FORMAT: CBOR array of instance-identifier

: The message payload of Content-Format 'application/yang-identifiers+cbor' is encoded using a CBOR array.
  Each entry of this CBOR array contain an instance-identifier encoded as defined in {{I-D.ietf-core-yang-cbor}} section 6.13.1.


application/yang-instances+cbor:

: This Content-Format represents a CBOR YANG document containing a list of data node instances.
  Each data node instance is identified by its associated instance-identifier.

: FORMAT: CBOR array of CBOR map of instance-identifier, instance-value

: The message payload of Content-Format 'application/yang-instances+cbor' is encoded using a CBOR array.
  Each entry within this CBOR array contains a CBOR map carrying an instance-identifier and associated instance-value.
  Instance-identifiers are encoded using the rules defined in {{I-D.ietf-core-yang-cbor}} section 6.13.1, instance-values are encoded using the rules defined in {{I-D.ietf-core-yang-cbor}} section 4.

: When present in an iPATCH request payload, this Content-Format carry a list of data node instances to be replaced, created, or deleted.
  For each data node instance D, for which the instance-identifier is the same as a data node instance I, in the targeted datastore resource: the value of D replaces the value of I.  When the value of D is null, the data node instance I is removed.  When the targeted datastore resource does not contain a data node instance with the same instance-identifier as D, a new instance is created with the same instance-identifier and value as D.


The different Content-format usages are summarized in the table below:

| Method         | Resource     | Content-Format                     |
| GET response   | data node    | /application/yang-data+cbor        |
| PUT request    | data node    | /application/yang-data+cbor        |
| POST request   | data node    | /application/yang-data+cbor        |
| DELETE         | data node    | n/a                                |
| GET response   | datastore    | /application/yang-data+cbor        |
| PUT request    | datastore    | /application/yang-data+cbor        |
| POST request   | datastore    | /application/yang-data+cbor        |
| FETCH request  | datastore    | /application/yang-identifiers+cbor |
| FETCH response | datastore    | /application/yang-instances+cbor   |
| iPATCH request | datastore    | /application/yang-instances+cbor   |
| GET response   | event stream | /application/yang-instances+cbor   |
| POST request   | rpc, action  | /application/yang-data+cbor        |
| POST response  | rpc, action  | /application/yang-data+cbor        |
{: align="left"}

## Unified datastore {#unified-datastore}

CoMI supports a simple datastore model consisting of a single unified datastore. This datastore provides access to both configuration and operational data. Configuration updates performed on this datastore are reflected immediately or with a minimal delay as operational data.

Alternatively, CoMI servers MAY implement a more complex datastore model such as the Network Management Datastore Architecture (NMDA) as defined by {{RFC8342}}. Each datastore supported is implemented as a datastore resource.

Characteristics of the unified datastore are summarized in the table below:

| Name          | Value                                             |
| Name          | unified                                           |
| YANG modules  | all modules                                       |
| YANG nodes    | all data nodes ("config true" and "config false") |
| Access        | read-write                                        |
| How applied   | changes applied in place immediately or with a  minimal delay |
| Protocols     | CORECONF                                          |
| Defined in    | "ietf-comi"                                       |
{: align="left"}

# Example syntax {#example-syntax}

CBOR is used to encode CoMI request and response payloads. The CBOR syntax
of the YANG payloads is specified in {{RFC7049}}. The payload examples are
notated in Diagnostic notation (defined in section 6 of {{RFC7049}}) that
can be automatically converted to CBOR.

SIDs in URIs are represented as a base64 number, SIDs in the payload are
represented as decimal numbers.

# CoAP Interface {#coap-interface}

This note specifies a Management Interface. CoAP endpoints that
implement the CoMI management protocol, support
at least one discoverable management resource of resource type (rt): core.c.ds,
with example path: /c, where c is short-hand for CoMI/CORECONF. The path /c is recommended,
but not compulsory (see {{discovery}}).

The mapping of YANG data node instances to CoMI resources is as follows.
Every data node of the YANG modules loaded in the CoMI server represents
a sub-resource of the datastore resource (e.g. /c/sid).
When multiple instances of a list exist, instance selection is possible
as described in {{query}}, {{get-example}}, and {{fetch}}.

CoMI also supports event stream resources used to observe notification instances.
Event stream resources can be discovered using resource type (rt): core.c.ev.

The description of the CoMI management interface is shown in the table below:

| CoAP resource        | Recommended path  | rt          |
| Datastore resource   | /c                | core.c.ds   |
| Data node resource   | /c/SID            | core.c.dn   |
| Event steam resource | /s                | core.c.ev   |
{: align="left"}

The path values in the table are the recommended ones. On discovery, the server makes the actual
path values known for these resources.

The methods used by CoMI are:

| Operation | Description |
| GET       | Retrieve the datastore resource or a data node resource |
| FETCH     | Retrieve specific data nodes within a datastore resource |
| POST      | Create a datastore resource or a data node resource, invoke an RPC or action |
| PUT       | Create or replace a datastore resource or a data node resource |
| iPATCH    | Idem-potently create, replace, and delete data node resource(s) within a datastore resource |
| DELETE    | Delete a datastore resource or a data node resource |
{: align="left"}

There is one Uri-Query option for the GET, PUT, POST, and DELETE methods.

| Uri-Query option | Description  |
| k                | Select an instance within YANG list(s) |
{: align="left"}

This parameter is not used for FETCH and iPATCH, because their request payloads
support list instance selection.


## Using the 'k' Uri-Query option {#query}

The "k" (key) parameter specifies a specific instance of a data node.
The SID in the URI is followed by the (?k=key1,key2,...). Where SID identifies
a data node, and key1, key2 are the values of the key leaves that specify
an instance. Lists can have multiple keys, and lists can be part
of lists. The order of key value generation is given recursively by:

* For a given list, if a parent data node is a list, generate the keys for the parent list first.

* For a given list, generate key values in the order specified in the YANG module.

Key values are encoded using the rules defined in the following table.

| YANG datatype               | Uri-Query text content          |
| uint8,uint16,unit32, uint64 | int2str(key)                    |
| int8, int16,int32, int64    | urlSafeBase64(CBORencode(key))  |
| decimal64                   | urlSafeBase64(CBOR key)         |
| string                      | key                             |
| boolean                     | "0" or "1"                      |
| enumeration                 | int2str(key)                    |
| bits                        | urlSafeBase64(CBORencode(key))  |
| binary                      | urlSafeBase64(key)              |
| identityref                 | int2str(key)                    |
| union                       | urlSafeBase64(CBORencode(key))  |
| instance-identifier         | urlSafeBase64(CBORencode(key))  |
{: align="left"}

In this table:

  * The method int2str() is used to convert an integer value to a decimal string. For example, int2str(0x0123) return  the string "291".

  * The method urlSafeBase64() is used to convert a binary string to base64 using the URL and Filename safe alphabet as defined by {{RFC4648}} section 5, without padding. For example, urlSafeBase64(\xF9\x56\xA1\x3C) return the string "-VahPA".

  * The method CBORencode() is used to convert a YANG value to CBOR as specified in {{I-D.ietf-core-yang-cbor}} section 6.

The resulting key string is encoded in a Uri-Query as specified in {{RFC7252}} section 6.5.


## Data Retrieval {#data-retrieval}

One or more data nodes can be retrieved by the client.
The operation is mapped to the GET method defined in
section 5.8.1 of {{RFC7252}} and to the FETCH method defined in section 2 of {{RFC8132}}.

There are two additional Uri-Query options for the GET and FETCH methods.

| Uri-Query option | Description |
|  c  |  Control selection of configuration and non-configuration data nodes (GET and FETCH)  |
|  d  |  Control retrieval of default values. |
{: align="left"}

### Using the 'c' Uri-Query option {#content}

The 'c' (content) option controls how descendant nodes of the
requested data nodes will be processed in the reply.

The allowed values are:

| Value | Description |
|  c    |  Return only configuration descendant data nodes |
|  n    |  Return only non-configuration descendant data nodes  |
|  a    |  Return all descendant data nodes  |
{: align="left"}

This option is only allowed for GET and FETCH methods on datastore and
data node resources.  A 4.02 (Bad Option) error is returned if used for other
methods or resource types.

If this Uri-Query option is not present, the default value is "a".


### Using the 'd' Uri-Query option {#dquery}

The "d" (with-defaults) option controls how the default values of the
descendant nodes of the requested data nodes will be processed.

The allowed values are:

| Value | Description |
| a     | All data nodes are reported. Defined as 'report-all' in section 3.1 of {{RFC6243}}. |
| t     | Data nodes set to the YANG default are not reported. Defined as 'trim' in section 3.2 of {{RFC6243}}. |
{: align="left"}

If the target of a GET or FETCH method is a data node that represents a leaf
that has a default value, and the leaf has not been given a value by any
client yet, the server MUST return the default value of the leaf.

If the target of a GET method is a data node that represents a
container or list that has child resources with default values,
and these have not been given value yet,

> The server MUST NOT return the child resource if d= 't'

> The server MUST return the child resource if d= 'a'.

If this Uri-Query option is not present, the default value is 't'.


### GET {#get-operation}

A request to read the value of a data node instance is sent with a
CoAP GET message. The URI is set to the data node resource requested,
the 'k' Uri-Query option is added if the data node is an instance of a list.

~~~~
FORMAT:
  GET <data node resource> ['k' Uri-Query option]

  2.05 Content (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value
~~~~
{: artwork-align="left"}

The returned payload contains the CBOR encoding of the requested instance-value.

#### GET Examples {#get-example}

Using for example the current-datetime leaf from module ietf-system {{RFC7317}}, a request is sent to
retrieve the value of 'system-state/clock/current-datetime'.
The SID of 'system-state/clock/current-datetime' is 1723, encoded in base64 according to {{id-compression}},
yields a7. The response to the request returns the CBOR map with the key set to the SID of the requested
data node (i.e. 1723) and the value encoded using a 'text string' as defined in {{I-D.ietf-core-yang-cbor}} section 6.4.

~~~~
REQ: GET example.com/c/a7

RES: 2.05 Content (Content-Format: application/yang-data+cbor)
{
  1723 : "2014-10-26T12:16:31Z"
}
~~~~
{: artwork-align="left"}

The next example represents the retrieval of a YANG container. In this
case, the CoMI client performs a GET request on the clock container
(SID = 1721; base64: a5). The container returned is encoded using a
CBOR map as specified by {{I-D.ietf-core-yang-cbor}} section 4.2.

~~~~
REQ: GET example.com/c/a5

RES: 2.05 Content (Content-Format: application/yang-data+cbor)
{
  1721 : {
    2 : "2014-10-26T12:16:51Z",    / current-datetime (SID 1723) /
    1 : "2014-10-21T03:00:00Z"     / boot-datetime (SID 1722) /
  }
}
~~~~
{: #Fig-get-system-current-datetime title='GET current datatime" artwork-align="left"}

This example shows the retrieval of the /interfaces/interface YANG list
accessed using SID 1533 (base64: X9). The return payload is encoded using
a CBOR array as specified by {{I-D.ietf-core-yang-cbor}} section 4.4.1
containing 2 instances.

~~~~
REQ: GET example.com/c/X9

RES: 2.05 Content (Content-Format: application/yang-data+cbor)
{
  1533 : [
    {
      4 : "eth0",                 / name  (SID 1537) /
      1 : "Ethernet adaptor",     / description (SID 1534) /
      5 : 1880,                   / type, (SID 1538) identity /
                                  / ethernetCsmacd (SID 1880) /
      2 : true                    / enabled (SID 1535) /
    },
    {
      4 : "eth1",                 / name (SID 1537) /
      1 : "Ethernet adaptor",     / description (SID 1534) /
      5 : 1880,                   / type, (SID 1538) identity /
                                  / ethernetCsmacd (SID 1880) /
      2 : false                   / enabled (SID 1535) /
    }
  ]
}
~~~~
{: artwork-align="left"}

To retrieve a specific instance within the /interfaces/interface YANG list,
the CoMI client adds the key of the targeted instance in its CoAP request
using the 'k' URI-Query. The return payload containing the instance requested
is encoded using a CBOR array as specified by {{I-D.ietf-core-yang-cbor}}
section 4.4.1 containing the requested instance.

~~~~
REQ: GET example.com/c/X9?k="eth0"

RES: 2.05 Content (Content-Format: application/yang-data+cbor)
{
  1533 : [
    {
      4 : "eth0",                 / name  (SID 1537) /
      1 : "Ethernet adaptor",     / description (SID 1534) /
      5 : 1880,                   / type, (SID 1538) identity /
                                  / ethernetCsmacd (SID 1880) /
      2 : true                    / enabled (SID 1535) /
    }
  ]
}
~~~~
{: artwork-align="left"}

It is equally possible to select a leaf of a specific instance of a list.
The example below requests the description leaf (SID 1534, base64: X-)
within the interface list corresponding to the interface name "eth0".
The returned value is encoded in CBOR based on the rules
specified by {{I-D.ietf-core-yang-cbor}} section 6.4.

~~~~
REQ: GET example.com/c/X-?k="eth0"

RES: 2.05 Content (Content-Format: application/yang-data+cbor)
{
  1534 : "Ethernet adaptor"
}
~~~~
{: artwork-align="left"}


### FETCH {#fetch}

The FETCH is used to retrieve multiple instance-values.
The FETCH request payload contains the list of instance-identifier of the data node instances requested.

The return response payload contains a list of data node instance-values in the same order as requested.
A CBOR null is returned for each data node requested by the client, not supported by the server or not currently instantiated.

For compactness, indexes of the list instance identifiers returned by the FETCH response SHOULD be elided, only the SID is provided.
This appraoch may also help reducing implementations complexity since the format of each entry within the CBOR array of the FETCH response is identical to the format of the corresponding GET response.

~~~~
FORMAT:
  FETCH <datastore resource>
        (Content-Format: application/yang-identifiers+cbor)
  CBOR array of instance-identifier

  2.05 Content (Content-Format: application/yang-instances+cbor)
  CBOR array of CBOR map of SID, instance-value
~~~~
{: artwork-align="left"}


#### FETCH examples {#fetch-example}

This example uses the current-datetime leaf from module ietf-system {{RFC7317}}
and the interface list from module ietf-interfaces {{RFC7223}}.
In this example the value of current-datetime (SID 1723) and the interface
list (SID 1533) instance identified with name="eth0" are queried.


~~~~
REQ: FETCH /c (Content-Format: application/yang-identifiers+cbor)
[
  1723,            / current-datetime (SID 1723) /
  [1533, "eth0"]   / interface (SID 1533) with name = "eth0" /
]

RES: 2.05 Content (Content-Format: application/yang-instances+cbor)
[
  {
    1723 : "2014-10-26T12:16:31Z" / current-datetime (SID 1723) /
  },
  {
    1533 : {
      4 : "eth0",                 / name (SID 1537) /
      1 : "Ethernet adaptor",     / description (SID 1534) /
      5 : 1880,                   / type (SID 1538), identity /
                                  / ethernetCsmacd (SID 1880) /
      2 : true                    / enabled (SID 1535) /
    }
  }
]
~~~~
{: artwork-align="left"}


## Data Editing {#data-editing}

CoMI allows datastore contents to be created, modified and deleted using
CoAP methods.

### Data Ordering {#DataOrdering}

A CoMI server MUST preserve the relative order of all user-ordered list
and leaf-list entries that are received in a single edit request.  These YANG
data node types are encoded as CBOR arrays so messages will preserve their
order.


### POST {#post-operation}

The CoAP POST operation is used in CoMI for creation of data node resources and the
invocation of "ACTION" and "RPC" resources.
Refer to {{rpc}} for details on "ACTION" and "RPC" resources.

A request to create a data node instance is sent with a CoAP POST message.
The URI specifies the data node resource of the instance to be created. In the case
of a list instance, keys MUST be present in the paylaod.

~~~~
FORMAT:
  POST <data node resource>
  (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value

  2.01 Created
~~~~
{: artwork-align="left"}

If the data node instance already exists, then the POST request MUST fail and
a "4.09 Conflict" response code MUST be returned

#### Post example {#post-example}

The example uses the interface list from  module ietf-interfaces {{RFC7223}}.
This example creates a new list instance within the interface list (SID = 1533):

~~~~
REQ: POST /c/X9 (Content-Format: application/yang-data+cbor)
{
  1533 : [
    {
      4 : "eth5",              / name (SID 1537) /
      1 : "Ethernet adaptor",  / description (SID 1534) /
      5 : 1880,                / type (SID 1538), identity /
                               / ethernetCsmacd (SID 1880) /
      2 : true                 / enabled (SID 1535) /
    }
  ]
}

RES: 2.01 Created
~~~~
{: artwork-align="left"}


### PUT {#put-operation}

A data node resource instance is created or replaced with the PUT method.
A request to set the value of a data node instance is sent with a
CoAP PUT message.

~~~~
FORMAT:
  PUT <data node resource> ['k' Uri-Query option]
           (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value

  2.01 Created
~~~~
{: artwork-align="left"}


#### PUT example {#put-example}

The example uses the interface list from module ietf-interfaces {{RFC7223}}.
This example updates the instance of the list interface (SID = 1533) with key
name="eth0":


~~~~
REQ: PUT /c/X9?k="eth0" (Content-Format: application/yang-data+cbor)
{
  1533 : [
    {
      4 : "eth0",              / name (SID 1537) /
      1 : "Ethernet adaptor",  / description (SID 1534) /
      5 : 1880,                / type (SID 1538), identity /
                               / ethernetCsmacd (SID 1880) /
      2 : true                 / enabled (SID 1535) /
    }
  ]
}

RES:  2.04 Changed
~~~~
{: artwork-align="left"}



### iPATCH {#ipatch-operation}

One or multiple data node instances are replaced with the idempotent
CoAP iPATCH method {{RFC8132}}.

There are no Uri-Query options for the iPATCH method.

The processing of the iPATCH command is specified by Content-Format 'application/yang-instances+cbor'.
In summary, if the CBOR patch payload contains a data node instance that is not present
in the target, this instance is added. If the target contains the specified instance,
the content of this instance is replaced with the value of the payload.
A null value indicates the removal of an existing data node instance.


~~~~
FORMAT:
  iPATCH <datastore resource>
         (Content-Format: application/yang-instances+cbor)
  CBOR array of CBOR map of instance-identifier, instance-value

  2.04 Changed
~~~~
{: artwork-align="left"}

#### iPATCH example {#ipatch-example}

In this example, a CoMI client requests the following operations:

  * Set "/system/ntp/enabled" (SID 1755) to true.

  * Remove the server "tac.nrc.ca" from the "/system/ntp/server" (SID 1756) list.

  * Add/set the server "NTP Pool server 2" to the list "/system/ntp/server" (SID 1756).

~~~~
REQ: iPATCH /c (Content-Format: application/yang-instances+cbor)
[
  {
    1755 : true                   / enabled (SID 1755) /
  },
  {
    [1756, "tac.nrc.ca"] : null   / server (SID 1756) /
  },
  {
    1756 : {                      / server (SID 1756) /
      3 : "tic.nrc.ca",           / name (SID 1759) /
      4 : true,                   / prefer (SID 1760) /
      5 : {                       / udp (SID 1761) /
        1 : "132.246.11.231"      / address (SID 1762) /
      }
    }
  }
]

RES: 2.04 Changed
~~~~
{: artwork-align="left"}



### DELETE {#delete-operation}

A data node resource is deleted with the DELETE method.


~~~~
FORMAT:
  Delete <data node resource> ['k' Uri-Query option]

  2.02 Deleted
~~~~
{: artwork-align="left"}


#### DELETE example {#delete-example}

This example uses the interface list from module ietf-interfaces {{RFC7223}}.
This example deletes an instance of the interface list (SID = 1533):


~~~~
REQ:   DELETE /c/X9?k="eth0"

RES:   2.02 Deleted
~~~~
{: artwork-align="left"}


## Full datastore access {#datastore-access}

The methods GET, PUT, POST, and DELETE can be used to request, replace, create,
and delete a whole datastore respectively.


~~~~
FORMAT:
  GET <datastore resource>

  2.05 Content (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value
~~~~
{: artwork-align="left"}

~~~~
FORMAT:
  PUT <datastore resource>
      (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value

  2.04 Changed
~~~~
{: artwork-align="left"}

~~~~
FORMAT:
  POST <datastore resource>
       (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value

  2.01 Created
~~~~
{: artwork-align="left"}

~~~~
FORMAT:
   DELETE <datastore resource>

  2.02 Deleted
~~~~
{: artwork-align="left"}

The content of the CBOR map represents the complete datastore of the server
at the GET indication of after a successful processing of a PUT or POST request.


### Full datastore examples {#datastore-example}

The example uses the interface list from module ietf-interfaces {{RFC7223}} and
the clock container from module ietf-system {{RFC7317}}.
We assume that the datastore contains two modules ietf-system (SID 1700) and
ietf-interfaces (SID 1500); they contain the 'interface' list (SID 1533) with
one instance and the 'clock' container (SID 1721). After invocation of GET, a
CBOR map with data nodes from these two modules is returned:


~~~~
REQ:  GET /c

RES: 2.05 Content (Content-Format: application/yang-data+cbor)
{
  1721 : {                       / Clock (SID 1721) /
    2: "2016-10-26T12:16:31Z",   / current-datetime (SID 1723) /
    1: "2014-10-05T09:00:00Z"    / boot-datetime (SID 1722) /
  },
  1533 : [
    {                              / interface (SID 1533) /
      4 : "eth0",                  / name (SID 1537) /
      1 : "Ethernet adaptor",      / description (SID 1534) /
      5 : 1880,                    / type (SID 1538), identity: /
                                   / ethernetCsmacd (SID 1880) /
      2 : true                     / enabled (SID 1535) /
    }
  ]
}
~~~~
{: artwork-align="left"}



## Event stream {#event-stream}

Event notification is an essential function for the management of servers.
CoMI allows notifications specified in YANG {{RFC5277}} to be reported to a list
of clients. The recommended path of the default event stream is /s.
The server MAY support additional event stream resources to address different
notification needs.

Reception of notification instances is enabled with the CoAP Observe
{{RFC7641}} function. Clients subscribe to the notifications by sending a
GET request with an "Observe" option, specifying the /s resource when the
default stream is selected.

Each response payload carries one or multiple notifications. The number of
notifications reported, and the conditions used to remove notifications
from the reported list is left to implementers.
When multiple notifications are reported, they MUST be ordered starting from
the newest notification at index zero.

The format of notification without any content is a null value. The format of
single notification is defined in {{I-D.ietf-core-yang-cbor}} section
4.2.1. For multiple notifications the format is an array where each element is
a single notification as described in {{I-D.ietf-core-yang-cbor}} section 4.2.1.

~~~~
FORMAT:
  GET <stream-resource> Observe(0)

  2.05 Content (Content-Format: application/yang-instances+cbor)
  CBOR array of CBOR map of instance-identifier, instance-value
~~~~
{: artwork-align="left"}

The array of data node instances may contain identical entries which have
been generated at different times.

An example implementation is:

> Every time an event is generated, the generated notification instance is
> appended to the chosen stream(s). After an aggregation period, which may be
> limited by the maximum number of notifications supported,
> the content of the instance is sent to all clients observing the modified stream.


### Notify Examples {#event-stream-example}

Let suppose the server generates the example-port-fault event as defined below.

~~~~
module example-port {
  ...
  notification example-port-fault {   // SID 60010
    description
      "Event generated if a hardware fault is detected";
    leaf port-name {                  // SID 60011
      type string;
    }
    leaf port-fault {                 // SID 60012
      type string;
    }
  }
}
~~~~
{: artwork-align="left"}

By executing a GET on the /s resource the client receives the following response:

~~~~
REQ:  GET /s Observe(0)

RES:  2.05 Content (Content-Format: application/yang-tree+cbor)
                        Observe(12)
[
  {
    60010 : {             / example-port-fault (SID 60010) /
      1 : "0/4/21",       / port-name (SID 60011) /
      2 : "Open pin 2"    / port-fault (SID 60012) /
    }
  },
  {
    60010 : {             / example-port-fault (SID 60010) /
      1 : "1/4/21",       / port-name (SID 60011) /
      2 : "Open pin 5"    / port-fault (SID 60012) /
    }
  }
]
~~~~
{: artwork-align="left"}

In the example, the request returns a success response with the contents
of the last two generated events. Consecutively the server will regularly
notify the client when a new event is generated.

To check that the client is still alive, the server MUST send Confirmable Message
periodically. When the client does not confirm the notification
from the server, the server will remove the client from the list of observers
{{RFC7641}}.

### The 'f' Uri-Query option

The 'f' (filter) option is used to indicate which subset of all possible notifications is of interest.  If not present, all notifications supported by the event stream are reported.

When not supported by a CoMI server, this option shall be ignored, all events notifications are reported independently of the presence and content of the 'f' (filter) option.

When present, this option contains a comma separated list of notification SIDs. For example, the following request returns notifications 60010 and 60020.

~~~~
REQ:  GET /s?f=60010,60020 Observe(0)
~~~~
{: artwork-align="left"}

## RPC statements {#rpc}

The YANG "action" and "RPC" statements specify the execution of a Remote
procedure Call (RPC) in the server.  It is invoked using a POST method to
an "Action" or "RPC" resource instance.

The request payload contains the values assigned to the input container when specified.
The response payload contains the values of the output container when specified.
Both the input and output containers are encoded in CBOR using the rules defined in
{{I-D.ietf-core-yang-cbor}} section 4.2.1.

The returned success response code is 2.05 Content.


~~~~
FORMAT:
  POST <data node resource> ['k' Uri-Query option]
           (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value

  2.05 Content (Content-Format: application/yang-data+cbor)
  CBOR map of SID, instance-value

~~~~
{: artwork-align="left"}


### RPC Example {#rpc-example}

The example is based on the YANG action "reset" as defined in {{RFC7950}} section 7.15.3
and annotated below with SIDs.

~~~~
module example-server-farm {
  yang-version 1.1;
  namespace "urn:example:server-farm";
  prefix "sfarm";

  import ietf-yang-types {
    prefix "yang";
  }

  list server {                        // SID 60000
    key name;
    leaf name {                        // SID 60001
      type string;
    }
    action reset {                     // SID 60002
      input {
        leaf reset-at {                // SID 60003
          type yang:date-and-time;
          mandatory true;
         }
       }
       output {
         leaf reset-finished-at {      // SID 60004
           type yang:date-and-time;
           mandatory true;
         }
       }
     }
   }
 }
~~~~
{: artwork-align="left"}

This example invokes the 'reset' action  (SID 60002, base64: Opq),
of the server instance with name equal to "myserver".


~~~~
REQ:  POST /c/Opq?k="myserver"
              (Content-Format: application/yang-data+cbor)
{
  60002 : {
    1 : "2016-02-08T14:10:08Z09:00" / reset-at (SID 60003) /
  }
}

RES:  2.05 Content (Content-Format: application/yang-data+cbor)
{
  60002 : {
    2 : "2016-02-08T14:10:08Z09:18" / reset-finished-at (SID 60004)/
  }
}
~~~~
{: artwork-align="left"}

# Use of Block-wise Transfers {#block}

The CoAP protocol provides reliability by acknowledging the UDP datagrams.
However, when large pieces of data need to be transported, datagrams get
fragmented, thus creating constraints on the resources in the client, server
and intermediate routers. The block option {{RFC7959}} allows the transport
of the total payload in individual blocks of which the
size can be adapted to the underlying transport sizes such as: (UDP datagram
size ~64KiB, IPv6 MTU of 1280, IEEE 802.15.4 payload of 60-80 bytes). Each
block is individually acknowledged to guarantee reliability.

Notice that the Block mechanism splits the data at fixed positions,
such that individual data fields may become fragmented. Therefore, assembly
of multiple blocks may be required to process complete data fields.

Beware of race conditions. Blocks are filled one at a time and care should
be taken that the whole data representation is sent in multiple blocks sequentially
without interruption. On the server, values are changed, lists are re-ordered,
extended or reduced. When these actions happen during the serialization of
the contents of the resource, the transported results do not correspond with
a state having occurred in the server; or worse the returned values are inconsistent.
For example: array length does not correspond with the actual number of items.
It may be advisable to use Indefinite-length CBOR arrays and maps,
which are foreseen for data streaming purposes.


# Application Discovery {#discovery}

Two application discovery mechanisms are supported by CoMI, the YANG library
data model as defined by {{I-D.ietf-core-yang-library}} and
the CORE resource discovery {{RFC6690}}.
Implementers may choose to implement one or the other or both.

## YANG library

The YANG library data model {{I-D.ietf-core-yang-library}} provides a high
level description of the resources available. The YANG library contains the
list of modules, features and deviations supported by the CoMI server.
From this information, CoMI clients can infer the list of data nodes supported
and the interaction model to be used to access them. This module also contains
the list of datastores implemented.

As described in {{RFC6690}}, the location of the YANG library can be found by
sending a GET request to
"/.well-known/core" including a resource type (RT) parameter with the value
"core.c.yl". Upon success, the return payload will contain the root resource
of the YANG library module.

The following example assumes that the SID of the YANG library is 2351 (kv
encoded as specified in {{id-compression}}).

~~~~
REQ: GET /.well-known/core?rt=core.c.yl

RES: 2.05 Content (Content-Format: application/link-format)
</c/kv>;rt="core.c.yl"
~~~~
{: artwork-align="left"}

## Resource Discovery

As some CoAP interfaces and services might not support the YANG library
interface and still be interested to discover resources that are available,
implementations MAY choose to support discovery of all available
resources using "/.well-known/core" as defined by {{RFC6690}}.

### Datastore Resource Discovery

The presence and location of (path to) each datastore implemented by the CoMI server
can be discovered by sending a GET request to "/.well-known/core" including a
resource type (RT) parameter with the value "core.c.ds".

Upon success, the return payload contains the list of datastore resources.

Each datastore returned is further qualified using the "ds" Link-Format attribute.
This attribute is set to the SID assigned to the datastore identity.
When a unified datastore is implemented, the ds attribute is set to 1029 as
specified in {{ietf-comi-sid}}.
For other examples of datastores, see the Network Management Datastore Architecture (NMDA) {{RFC7950}}.

~~~~
link-extension    = ( "ds" "=" sid ) )
                    ; SID assigned to the datastore identity
sid               = 1*DIGIT
~~~~
{: artwork-align="left"}


For example:

~~~~
REQ: GET /.well-known/core?rt=core.c.ds

RES: 2.05 Content (Content-Format: application/link-format)
</c>; rt="core.c.ds";ds=1029
~~~~
{: artwork-align="left"}

### Data node Resource Discovery

If implemented, the presence and location of (path to) each data node
implemented by the CoMI server are discovered by sending a GET request to
"/.well-known/core" including a resource type (RT) parameter with the value
"core.c.dn".

Upon success, the return payload contains the SID assigned to each data node
and their location.

The example below shows the discovery of the presence and location of
data nodes. Data nodes '/ietf-system:system-state/clock/boot-datetime' (SID 1722)
and '/ietf-system:system-state/clock/current-datetime' (SID 1723) are returned.


~~~~
REQ: GET /.well-known/core?rt=core.c.dn

RES: 2.05 Content (Content-Format: application/link-format)
</c/a6>;rt="core.c.dn",
</c/a7>;rt="core.c.dn"
~~~~
{: artwork-align="left"}

Without additional filtering, the list of data nodes may become prohibitively
long. If this is the case implementations SHOULD support a way to obtain all
links using multiple GET requests (for example through some form of
pagination).

### Event stream Resource Discovery

The presence and location of (path to) each event stream implemented by the CoMI server are
discovered by sending a GET request to "/.well-known/core" including a resource type (RT)
parameter with the value "core.c.es".

Upon success, the return payload contains the list of event stream resources.

For example:

~~~~
REQ: GET /.well-known/core?rt=core.c.es

RES: 2.05 Content (Content-Format: application/link-format)
</s>;rt="core.c.es"
~~~~
{: artwork-align="left"}


# Error Handling {#error-handling}

In case a request is received which cannot be processed properly, the CoMI server MUST return an error response. This error response MUST contain a CoAP 4.xx or 5.xx response code.

Errors returned by a CoMI server can be broken into two categories, those associated to the CoAP protocol itself and those generated during the validation of the YANG data model constrains as described in {{RFC7950}} section 8.

The following list of common CoAP errors should be implemented by CoMI servers. This list is not exhaustive, other errors defined by CoAP and associated RFCs may be applicable.

* Error 4.01 (Unauthorized) is returned by the CoMI server when the CoMI client is not authorized to perform the requested action on the targeted resource (i.e. data node, datastore, rpc, action or event stream).

* Error 4.02 (Bad Option) is returned by the CoMI server when one or more CoAP options are unknown or malformed.

* Error 4.04 (Not Found) is returned by the CoMI server when the CoMI client is requesting a non-instantiated resource (i.e. data node, datastore, rpc, action or event stream).

* Error 4.05 (Method Not Allowed) is returned by the CoMI server when the CoMI client is requesting a method not supported on the targeted resource. (e.g. GET on an rpc, PUT or POST on a data node with "config" set to false).

* Error 4.08 (Request Entity Incomplete) is returned by the CoMI server if one or multiple blocks of a block transfer request is missing, see {{RFC7959}} for more details.

* Error 4.13 (Request Entity Too Large) may be returned by the CoMI server during a block transfer request, see {{RFC7959}} for more details.

* Error 4.15 (Unsupported Content-Format) is returned by the CoMI server when the Content-Format used in the request does not match those specified in section {{content-format}}.


The CoMI server MUST also enforce the different constraints associated to the YANG data models implemented. These constraints are described in {{RFC7950}} section 8. These errors are reported using the CoAP error code 4.00 (Bad Request) and may have the following error container as payload. The YANG definition and associated .sid file are available in {{ietf-comi-yang}} and {{ietf-comi-sid}}. The error container is encoded using the encoding rules of a YANG data template as defined in {{I-D.ietf-core-yang-cbor}} section 5.

~~~~
+--rw error!
   +--rw error-tag             identityref
   +--rw error-app-tag?        identityref
   +--rw error-data-node?      instance-identifier
   +--rw error-message?        string
~~~~
{: artwork-align="left"}

The following 'error-tag' and 'error-app-tag' are defined by the ietf-comi YANG module, these tags are implemented as YANG identity and can be extended as needed.

* error-tag 'operation-failed' is returned by the CoMI server when the operation request cannot be processed successfully.

  * error-app-tag 'malformed-message' is returned by the CoMI server when the payload received from the CoMI client does not contain a well-formed CBOR content as defined in {{RFC7049}} section 3.3 or does not comply with the CBOR structure defined within this document.

  * error-app-tag 'data-not-unique' is returned by the CoMI server when the validation of the 'unique' constraint of a list or leaf-list fails.

  * error-app-tag 'too-many-elements' is returned by the CoMI server when the validation of the 'max-elements' constraint of a list or leaf-list fails.

  * error-app-tag 'too-few-elements' is returned by the CoMI server when the validation of the 'min-elements' constraint of a list or leaf-list fails.

  * error-app-tag 'must-violation' is returned by the CoMI server when the restrictions imposed by a 'must' statement are violated.

  * error-app-tag 'duplicate' is returned by the CoMI server when a client tries to create a duplicate list or leaf-list entry.

* error-tag 'invalid-value' is returned by the CoMI server when the CoMI client tries to update or create a leaf with a value encoded using an invalid CBOR datatype or if the 'range', 'length', 'pattern' or 'require-instance' constrain is not fulfilled.

  * error-app-tag 'invalid-datatype' is returned by the CoMI server when CBOR encoding does not follow the rules set by the YANG Build-In type or when the value is incompatible with it (e.g. a value greater than 127 for an int8, undefined enumeration).

  * error-app-tag 'not-in-range' is returned by the CoMI server when the validation of the 'range' property fails.

  * error-app-tag 'invalid-length' is returned by the CoMI server when the validation of the 'length' property fails.

  * error-app-tag 'pattern-test-failed' is returned by the CoMI server when the validation of the 'pattern' property fails.

* error-tag 'missing-element' is returned by the CoMI server when the operation requested by a CoMI client fails to comply with the 'mandatory' constraint defined. The 'mandatory' constraint is enforced for leafs and choices, unless the node or any of its ancestors have a 'when' condition or 'if-feature' expression that evaluates to 'false'.

  * error-app-tag 'missing-key' is returned by the CoMI server to further qualify a missing-element error. This error is returned when the CoMI client  tries to create or list instance, without all the 'key' specified or when the CoMI client  tries to delete a leaf listed as a 'key'.

  * error-app-tag 'missing-input-parameter' is returned by the CoMI server when the input parameters of an RPC or action are incomplete.

* error-tag 'unknown-element' is returned by the CoMI server when the CoMI client  tries to access a data node of a YANG module not supported, of a data node associated to an 'if-feature' expression evaluated to 'false' or to a 'when' condition evaluated to 'false'.

* error-tag 'bad-element' is returned by the CoMI server when the CoMI client  tries to create data nodes for more than one case in a choice.

* error-tag 'data-missing' is returned by the CoMI server when a data node required to accept the request is not present.

  * error-app-tag 'instance-required' is returned by the CoMI server when a leaf of type 'instance-identifier' or 'leafref' marked with require-instance set to 'true' refers to an instance that does not exist.

  * error-app-tag 'missing-choice' is returned by the CoMI server when no nodes exist in a mandatory choice.

* error-tag 'error' is returned by the CoMI server when an unspecified error has occurred.

For example, the CoMI server might return the following error.

~~~~
RES:  4.00 Bad Request (Content-Format: application/yang-data+cbor)
{
  1024 : {
    4 : 1011,        / error-tag (SID 1028) /
                     /   = invalid-value (SID 1011) /
    1 : 1018,        / error-app-tag (SID 1025) /
                     /   = not-in-range (SID 1018) /
    2 : 1740,        / error-data-node (SID 1026) /
                     /   = timezone-utc-offset (SID 1740) /
    3 : "maximum value exceeded" / error-message (SID 1027) /
  }
}
~~~~
{: artwork-align="left"}


# Security Considerations

For secure network management, it is important to restrict access to configuration variables
only to authorized parties. CoMI re-uses the security mechanisms already available to CoAP,
this includes DTLS {{RFC6347}} for protected access to resources, as well suitable
authentication and authorization mechanisms.

Among the security decisions that need to be made are selecting security modes and encryption
mechanisms (see {{RFC7252}}).

In addition, mechanisms for authentication and authorization may need to be selected if not provided with the security mode.

# IANA Considerations

## Resource Type (rt=) Link Target Attribute Values Registry

This document adds the following resource type to the "Resource Type (rt=) Link Target Attribute Values", within the "Constrained RESTful Environments (CoRE) Parameters" registry.

| Value       | Description         | Reference |
| core.c.ds   | YANG datastore      | RFC XXXX  |
| core.c.dn   | YANG data node      | RFC XXXX  |
| core.c.yl   | YANG module library | RFC XXXX  |
| core.c.es   | YANG event stream   | RFC XXXX  |
{: align="left"}

// RFC Ed.: replace RFC XXXX with this RFC number and remove this note.

## CoAP Content-Formats Registry

This document adds the following Content-Format to the "CoAP Content-Formats", within the "Constrained RESTful Environments (CoRE) Parameters" registry.

| Media Type                        | Content Coding | ID   | Reference |
| application/yang-data+cbor        |                | TBD1 | RFC XXXX  |
| application/yang-identifiers+cbor |                | TBD2 | RFC XXXX  |
| application/yang-instances+cbor   |                | TBD3 | RFC XXXX  |
{: align="left"}

// RFC Ed.: replace TBD1, TBD2 and TBD3 with assigned IDs and remove this note.
// RFC Ed.: replace RFC XXXX with this RFC number and remove this note.

## Media Types Registry

This document adds the following media types to the "Media Types" registry.

| Name                  | Template                    | Reference |
| yang-data+cbor        | application/yang-data+cbor  | RFC XXXX  |
| yang-identifiers+cbor | application/                | RFC XXXX  |
|                       | yang-identifiers+cbor       |           |
| yang-instances+cbor   | application/                | RFC XXXX  |
|                       | yang-instances+cbor         |           |
{: align="left"}

Each of these media types share the following information:

  *  Subtype name: \<as listed in table>

  *  Required parameters: N/A

  *  Optional parameters: N/A

  *  Encoding considerations: binary

  *  Security considerations: See the Security Considerations section of RFC XXXX

  *  Interoperability considerations: N/A

  *  Published specification: RFC XXXX

  *  Applications that use this media type: CoMI

  *  Fragment identifier considerations: N/A

  *  Additional information:

    *  Deprecated alias names for this type: N/A

    *  Magic number(s): N/A

    *  File extension(s): N/A

    *  Macintosh file type code(s): N/A

  *  Person & email address to contact for further information: iesg&ietf.org

  *  Intended usage: COMMON

  *  Restrictions on usage: N/A

  *  Author: Michel Veillette, ietf&augustcellars.com

  *  Change Controller: IESG

  *  Provisional registration?  No

// RFC Ed.: replace RFC XXXX with this RFC number and remove this note.


# Acknowledgements

We are very grateful to Bert Greevenbosch who was one of the original authors
of the CoMI specification.

Mehmet Ersue and Bert Wijnen explained the encoding aspects of PDUs transported
under SNMP. Carsten Bormann has given feedback on the use of CBOR.

The draft has benefited from comments (alphabetical order) by Rodney Cummings,
Dee Denteneer, Esko Dijk, Michael van Hartskamp, Tanguy Ropitault, Juergen
Schoenwaelder, Anuj Sehgal, Zach Shelby, Hannes Tschofenig, Michael Verschoor,
and Thomas Watteyne.


--- back

# ietf-comi YANG module {#ietf-comi-yang}

~~~~
<CODE BEGINS> file "ietf-comi@2019-03-28.yang"
module ietf-comi {
  yang-version 1.1;

  namespace "urn:ietf:params:xml:ns:yang:ietf-comi";
  prefix comi;

  import ietf-datastores {
    prefix ds;
  }

  import ietf-restconf {
    prefix rc;
    description
      "This import statement is required to access
       the yang-data extension defined in RFC 8040.";
    reference "RFC 8040: RESTCONF Protocol";
  }

  organization
    "IETF Core Working Group";

  contact
    "Michel Veillette
     <mailto:michel.veillette@trilliantinc.com>

     Alexander Pelov
     <mailto:alexander@ackl.io>

     Peter van der Stok
     <mailto:consultancy@vanderstok.org>

     Andy Bierman
     <mailto:andy@yumaworks.com>";

  description
    "This module contains the different definitions required
     by the CoMI protocol.
     
     Copyright (c) 2019 IETF Trust and the persons identified as
     authors of the code.  All rights reserved.

     Redistribution and use in source and binary forms, with or
     without modification, is permitted pursuant to, and subject to
     the license terms contained in, the Simplified BSD License set
     forth in Section 4.c of the IETF Trust's Legal Provisions
     Relating to IETF Documents
     (https://trustee.ietf.org/license-info).

     This version of this YANG module is part of RFC XXXX;
     see the RFC itself for full legal notices.";

  revision 2019-03-28 {
     description
      "Initial revision.";
    reference
      "[I-D.ietf-core-comi] CoAP Management Interface";
  }

  identity unified {
    base ds:datastore;
    description
      "Identifier of the unified configuration and operational
       state datastore.";
  }

  identity error-tag {
    description
      "Base identity for error-tag.";
  }

  identity operation-failed {
    base error-tag;
    description
      "Returned by the CoMI server when the operation request
       can't be processed successfully.";
  }

  identity invalid-value {
    base error-tag;
    description
      "Returned by the CoMI server when the CoMI client tries to
       update or create a leaf with a value encoded using an
       invalid CBOR datatype or if the 'range', 'length',
       'pattern' or 'require-instance' constrain is not
       fulfilled.";
  }

  identity missing-element {
    base error-tag;
    description
      "Returned by the CoMI server when the operation requested
       by a CoMI client fails to comply with the 'mandatory'
       constraint defined. The 'mandatory' constraint is
       enforced for leafs and choices, unless the node or any of
       its ancestors have a 'when' condition or 'if-feature'
       expression that evaluates to 'false'.";
  }

  identity unknown-element {
    base error-tag;
    description
      "Returned by the CoMI server when the CoMI client tries to
       access a data node of a YANG module not supported, of a
       data node associated with an 'if-feature' expression
       evaluated to 'false' or to a 'when' condition evaluated
       to 'false'.";
  }

  identity bad-element {
    base error-tag;
    description
      "Returned by the CoMI server when the CoMI client tries to
       create data nodes for more than one case in a choice.";
  }

  identity data-missing {
    base error-tag;
    description
      "Returned by the CoMI server when a data node required to
       accept the request is not present.";
  }

  identity error {
    base error-tag;
    description
      "Returned by the CoMI server when an unspecified error has
      occurred.";
  }

  identity error-app-tag {
    description
      "Base identity for error-app-tag.";
  }

  identity malformed-message {
    base error-app-tag;
    description
      "Returned by the CoMI server when the payload received
       from the CoMI client don't contain a well-formed CBOR
       content as defined in [RFC7049] section 3.3 or don't
       comply with the CBOR structure defined within this
       document.";
  }

  identity data-not-unique {
    base error-app-tag;
    description
      "Returned by the CoMI server when the validation of the
       'unique' constraint of a list or leaf-list fails.";
  }

  identity too-many-elements {
    base error-app-tag;
    description
      "Returned by the CoMI server when the validation of the
       'max-elements' constraint of a list or leaf-list fails.";
  }

  identity too-few-elements {
    base error-app-tag;
    description
      "Returned by the CoMI server when the validation of the
       'min-elements' constraint of a list or leaf-list fails.";
  }

  identity must-violation {
    base error-app-tag;
    description
      "Returned by the CoMI server when the restrictions
       imposed by a 'must' statement are violated.";
  }

  identity duplicate {
    base error-app-tag;
    description
      "Returned by the CoMI server when a client tries to create
       a duplicate list or leaf-list entry.";
  }

  identity invalid-datatype {
    base error-app-tag;
    description
      "Returned by the CoMI server when CBOR encoding is
       incorect or when the value encoded is incompatible with
       the YANG Built-In type. (e.g. value greater than 127
       for an int8, undefined enumeration).";
  }

  identity not-in-range {
    base error-app-tag;
    description
      "Returned by the CoMI server when the validation of the
       'range' property fails.";
  }

  identity invalid-length {
    base error-app-tag;
    description
      "Returned by the CoMI server when the validation of the
       'length' property fails.";
  }

  identity pattern-test-failed {
    base error-app-tag;
    description
      "Returned by the CoMI server when the validation of the
       'pattern' property fails.";
  }

  identity missing-key {
    base error-app-tag;
    description
      "Returned by the CoMI server to further qualify a
       missing-element error. This error is returned when the
       CoMI client tries to create or list instance, without all
       the 'key' specified or when the CoMI client tries to
       delete a leaf listed as a 'key'.";
  }

  identity missing-input-parameter {
    base error-app-tag;
    description
      "Returned by the CoMI server when the input parameters
       of a RPC or action are incomplete.";
  }

  identity instance-required {
    base error-app-tag;
    description
      "Returned by the CoMI server when a leaf of type
       'instance-identifier' or 'leafref' marked with
       require-instance set to 'true' refers to an instance
       that does not exist.";
  }

  identity missing-choice {
    base error-app-tag;
    description
      "Returned by the CoMI server when no nodes exist in a
       mandatory choice.";
  }

  rc:yang-data comi-error {
    container error {
      description
        "Optional payload of a 4.00 Bad Request CoAP error.";

      leaf error-tag {
        type identityref {
          base error-tag;
        }
        mandatory true;
        description
          "The enumerated error-tag.";
      }

      leaf error-app-tag {
        type identityref {
          base error-app-tag;
        }
        description
          "The application-specific error-tag.";
      }

      leaf error-data-node {
        type instance-identifier;
        description
          "When the error reported is caused by a specific data node,
           this leaf identifies the data node in error.";
      }

      leaf error-message {
        type string;
        description
          "A message describing the error.";
      }
    }
  }
}
<CODE ENDS>
~~~~
{: artwork-align="left"}

# ietf-comi .sid file {#ietf-comi-sid}

~~~~
{
  "assignment-ranges": [
    {
      "entry-point": 1000,
      "size": 100
    }
  ],
  "module-name": "ietf-comi",
  "module-revision": "2019-03-28",
  "items": [
    {
      "namespace": "module",
      "identifier": "ietf-comi",
      "sid": 1000
    },
    {
      "namespace": "identity",
      "identifier": "bad-element",
      "sid": 1001
    },
    {
      "namespace": "identity",
      "identifier": "data-missing",
      "sid": 1002
    },
    {
      "namespace": "identity",
      "identifier": "data-not-unique",
      "sid": 1003
    },
    {
      "namespace": "identity",
      "identifier": "duplicate",
      "sid": 1004
    },
    {
      "namespace": "identity",
      "identifier": "error",
      "sid": 1005
    },
    {
      "namespace": "identity",
      "identifier": "error-app-tag",
      "sid": 1006
    },
    {
      "namespace": "identity",
      "identifier": "error-tag",
      "sid": 1007
    },
    {
      "namespace": "identity",
      "identifier": "instance-required",
      "sid": 1008
    },
    {
      "namespace": "identity",
      "identifier": "invalid-datatype",
      "sid": 1009
    },
    {
      "namespace": "identity",
      "identifier": "invalid-length",
      "sid": 1010
    },
    {
      "namespace": "identity",
      "identifier": "invalid-value",
      "sid": 1011
    },
    {
      "namespace": "identity",
      "identifier": "malformed-message",
      "sid": 1012
    },
    {
      "namespace": "identity",
      "identifier": "missing-choice",
      "sid": 1013
    },
    {
      "namespace": "identity",
      "identifier": "missing-element",
      "sid": 1014
    },
    {
      "namespace": "identity",
      "identifier": "missing-input-parameter",
      "sid": 1015
    },
    {
      "namespace": "identity",
      "identifier": "missing-key",
      "sid": 1016
    },
    {
      "namespace": "identity",
      "identifier": "must-violation",
      "sid": 1017
    },
    {
      "namespace": "identity",
      "identifier": "not-in-range",
      "sid": 1018
    },
    {
      "namespace": "identity",
      "identifier": "operation-failed",
      "sid": 1019
    },
    {
      "namespace": "identity",
      "identifier": "pattern-test-failed",
      "sid": 1020
    },
    {
      "namespace": "identity",
      "identifier": "too-few-elements",
      "sid": 1021
    },
    {
      "namespace": "identity",
      "identifier": "too-many-elements",
      "sid": 1022
    },
    {
      "namespace": "identity",
      "identifier": "unified",
      "sid": 1029
    },
    {
      "namespace": "identity",
      "identifier": "unknown-element",
      "sid": 1023
    },
    {
      "namespace": "data",
      "identifier": "/ietf-comi:error",
      "sid": 1024
    },
    {
      "namespace": "data",
      "identifier": "/ietf-comi:error/error-app-tag",
      "sid": 1025
    },
    {
      "namespace": "data",
      "identifier": "/ietf-comi:error/error-data-node",
      "sid": 1026
    },
    {
      "namespace": "data",
      "identifier": "/ietf-comi:error/error-message",
      "sid": 1027
    },
    {
      "namespace": "data",
      "identifier": "/ietf-comi:error/error-tag",
      "sid": 1028
    }
  ]
}
~~~~
{: artwork-align="left"}



