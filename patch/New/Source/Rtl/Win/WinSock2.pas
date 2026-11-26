{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     Windows Sockets 2 (ws2_32.dll)                       }
{     Windows XP .. Windows 11                             }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit WinSock2;

{ Translated from winsock2.h, ws2def.h, ws2ipdef.h, ws2tcpip.h, inaddr.h,
  in6addr.h, qos.h, mswsock.h and mstcpip.h (Windows SDK 10.0.26100). The
  selection is curated, not exhaustive: the BSD socket functions, the WSA*
  functions of Winsock 2, getaddrinfo / getnameinfo and the Windows Vista
  additions (inet_pton, inet_ntop, WSAPoll, GetAddrInfoExW,
  WSAConnectByName, WSASendMsg), with their structures and constants, and
  the mswsock.h extension functions that WSAIoctl returns for
  SIO_GET_EXTENSION_FUNCTION_POINTER (AcceptEx, ConnectEx, DisconnectEx,
  GetAcceptExSockaddrs, TransmitFile, WSARecvMsg).

  WinSock2 is independent of WinSock.pas (Winsock 1.1, wsock32.dll) and uses
  only Windows. Both units declare many of the same names (TSocket, TFDSet,
  sockaddr_in, accept ...), so a unit should use one of them. Differences
  from WinSock.pas: TSockAddr is sockaddr (sa_family, sa_data), not
  sockaddr_in; TSocket and u_long are unsigned; address parameters are
  pointers (PSockAddr), so that sockaddr_in, sockaddr_in6 and
  sockaddr_storage are passed with @.

  Binding:
    - functions that ws2_32.dll exports on Windows XP are bound statically
      (external ws2_32);
    - functions introduced later (GetAddrInfoW, FreeAddrInfoW and
      GetNameInfoW in Windows XP SP2; inet_pton, inet_ntop, InetPtonW,
      InetNtopW, WSAPoll, GetAddrInfoExW, FreeAddrInfoExW, WSAConnectByNameA,
      WSAConnectByNameW and WSASendMsg in Windows Vista) are bound at run
      time on first use, so programs that use this unit still start on
      Windows XP. ws2_32.dll is loaded by full path from the system
      directory. When the export is missing, the function fails with
      WSAGetLastError = WSAVERNOTSUPPORTED; its return value in that case is
      documented next to its declaration.
  Generic names (without A or W) are the ANSI functions and structures, as
  in Windows.pas.

  Pascal names that differ from C:
    - fd_set is TFDSet and SOCKET is TSocket: the procedure FD_SET (the
      macro of C) and the function socket are the same Pascal identifiers.
    - in_addr has the C member S_un and, as variant fields at the top level,
      the members of S_un, so that the s_addr macro of C (a.s_addr) is
      written the same way (a.S_addr). in6_addr has the C member u and the
      macros s6_addr, s6_bytes and s6_words as variant fields.
    - sockaddr_in6: the anonymous union of sin6_scope_id and
      sin6_scope_struct is the field sin6_scope_id.
    - Parameters named after Pascal reserved words: type -> type_,
      to -> addrto, in -> inaddr.
    - size_t is ULONG_PTR.
  Records have the default alignment, which gives the layouts of 32-bit
  MSVC (checked by probes\api\winsock2test.dpr). }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}

interface

uses
  Windows;

{ ====== Basic types (winsock2.h, ws2def.h, ws2tcpip.h, qos.h) ============= }

type
  {$EXTERNALSYM u_char}
  u_char = Byte;
  {$EXTERNALSYM u_short}
  u_short = Word;
  {$EXTERNALSYM u_int}
  u_int = Cardinal;
  {$EXTERNALSYM u_long}
  u_long = Cardinal;

  { SOCKET (UINT_PTR) }
  TSocket = UINT_PTR;
  PSocket = ^TSocket;

  {$EXTERNALSYM ADDRESS_FAMILY}
  ADDRESS_FAMILY = Word;
  {$EXTERNALSYM GROUP}
  GROUP = u_int;
  PGroup = ^GROUP;
  {$EXTERNALSYM WSAEVENT}
  WSAEVENT = THandle;
  {$EXTERNALSYM LPWSAEVENT}
  LPWSAEVENT = ^WSAEVENT;
  PWSAEvent = LPWSAEVENT;
  {$EXTERNALSYM socklen_t}
  socklen_t = Integer;
  {$EXTERNALSYM SERVICETYPE}
  SERVICETYPE = ULONG;

  {$EXTERNALSYM WSAOVERLAPPED}
  WSAOVERLAPPED = TOverlapped;
  TWSAOverlapped = TOverlapped;
  {$EXTERNALSYM LPWSAOVERLAPPED}
  LPWSAOVERLAPPED = POverlapped;
  PWSAOverlapped = POverlapped;

{ ====== Limits and special values ======================================== }

const
  {$EXTERNALSYM WINSOCK_VERSION}
  WINSOCK_VERSION = $0202;                { MAKEWORD(2, 2) }
  {$EXTERNALSYM WSADESCRIPTION_LEN}
  WSADESCRIPTION_LEN = 256;
  {$EXTERNALSYM WSASYS_STATUS_LEN}
  WSASYS_STATUS_LEN = 128;
  {$EXTERNALSYM FD_SETSIZE}
  FD_SETSIZE = 64;
  {$EXTERNALSYM INVALID_SOCKET}
  INVALID_SOCKET = TSocket(not 0);
  {$EXTERNALSYM SOCKET_ERROR}
  SOCKET_ERROR = -1;
  {$EXTERNALSYM FROM_PROTOCOL_INFO}
  FROM_PROTOCOL_INFO = -1;
  {$EXTERNALSYM SOMAXCONN}
  SOMAXCONN = $7FFFFFFF;
  {$EXTERNALSYM MAXGETHOSTSTRUCT}
  MAXGETHOSTSTRUCT = 1024;
  {$EXTERNALSYM MSG_MAXIOVLEN}
  MSG_MAXIOVLEN = 16;

{ ====== Address families, socket types, protocols (ws2def.h) ============= }

const
  {$EXTERNALSYM AF_UNSPEC}
  AF_UNSPEC     = 0;
  {$EXTERNALSYM AF_UNIX}
  AF_UNIX       = 1;
  {$EXTERNALSYM AF_INET}
  AF_INET       = 2;
  {$EXTERNALSYM AF_IMPLINK}
  AF_IMPLINK    = 3;
  {$EXTERNALSYM AF_PUP}
  AF_PUP        = 4;
  {$EXTERNALSYM AF_CHAOS}
  AF_CHAOS      = 5;
  {$EXTERNALSYM AF_NS}
  AF_NS         = 6;
  {$EXTERNALSYM AF_IPX}
  AF_IPX        = AF_NS;
  {$EXTERNALSYM AF_ISO}
  AF_ISO        = 7;
  {$EXTERNALSYM AF_OSI}
  AF_OSI        = AF_ISO;
  {$EXTERNALSYM AF_ECMA}
  AF_ECMA       = 8;
  {$EXTERNALSYM AF_DATAKIT}
  AF_DATAKIT    = 9;
  {$EXTERNALSYM AF_CCITT}
  AF_CCITT      = 10;
  {$EXTERNALSYM AF_SNA}
  AF_SNA        = 11;
  {$EXTERNALSYM AF_DECnet}
  AF_DECnet     = 12;
  {$EXTERNALSYM AF_DLI}
  AF_DLI        = 13;
  {$EXTERNALSYM AF_LAT}
  AF_LAT        = 14;
  {$EXTERNALSYM AF_HYLINK}
  AF_HYLINK     = 15;
  {$EXTERNALSYM AF_APPLETALK}
  AF_APPLETALK  = 16;
  {$EXTERNALSYM AF_NETBIOS}
  AF_NETBIOS    = 17;
  {$EXTERNALSYM AF_VOICEVIEW}
  AF_VOICEVIEW  = 18;
  {$EXTERNALSYM AF_FIREFOX}
  AF_FIREFOX    = 19;
  {$EXTERNALSYM AF_UNKNOWN1}
  AF_UNKNOWN1   = 20;
  {$EXTERNALSYM AF_BAN}
  AF_BAN        = 21;
  {$EXTERNALSYM AF_ATM}
  AF_ATM        = 22;
  {$EXTERNALSYM AF_INET6}
  AF_INET6      = 23;
  {$EXTERNALSYM AF_CLUSTER}
  AF_CLUSTER    = 24;
  {$EXTERNALSYM AF_12844}
  AF_12844      = 25;
  {$EXTERNALSYM AF_IRDA}
  AF_IRDA       = 26;
  {$EXTERNALSYM AF_NETDES}
  AF_NETDES     = 28;
  {$EXTERNALSYM AF_TCNPROCESS}
  AF_TCNPROCESS = 29;
  {$EXTERNALSYM AF_TCNMESSAGE}
  AF_TCNMESSAGE = 30;
  {$EXTERNALSYM AF_ICLFXBM}
  AF_ICLFXBM    = 31;
  {$EXTERNALSYM AF_BTH}
  AF_BTH        = 32;
  {$EXTERNALSYM AF_LINK}
  AF_LINK       = 33;
  {$EXTERNALSYM AF_HYPERV}
  AF_HYPERV     = 34;
  {$EXTERNALSYM AF_MAX}
  AF_MAX        = 35;

  {$EXTERNALSYM PF_UNSPEC}
  PF_UNSPEC     = AF_UNSPEC;
  {$EXTERNALSYM PF_UNIX}
  PF_UNIX       = AF_UNIX;
  {$EXTERNALSYM PF_INET}
  PF_INET       = AF_INET;
  {$EXTERNALSYM PF_IMPLINK}
  PF_IMPLINK    = AF_IMPLINK;
  {$EXTERNALSYM PF_PUP}
  PF_PUP        = AF_PUP;
  {$EXTERNALSYM PF_CHAOS}
  PF_CHAOS      = AF_CHAOS;
  {$EXTERNALSYM PF_NS}
  PF_NS         = AF_NS;
  {$EXTERNALSYM PF_IPX}
  PF_IPX        = AF_IPX;
  {$EXTERNALSYM PF_ISO}
  PF_ISO        = AF_ISO;
  {$EXTERNALSYM PF_OSI}
  PF_OSI        = AF_OSI;
  {$EXTERNALSYM PF_ECMA}
  PF_ECMA       = AF_ECMA;
  {$EXTERNALSYM PF_DATAKIT}
  PF_DATAKIT    = AF_DATAKIT;
  {$EXTERNALSYM PF_CCITT}
  PF_CCITT      = AF_CCITT;
  {$EXTERNALSYM PF_SNA}
  PF_SNA        = AF_SNA;
  {$EXTERNALSYM PF_DECnet}
  PF_DECnet     = AF_DECnet;
  {$EXTERNALSYM PF_DLI}
  PF_DLI        = AF_DLI;
  {$EXTERNALSYM PF_LAT}
  PF_LAT        = AF_LAT;
  {$EXTERNALSYM PF_HYLINK}
  PF_HYLINK     = AF_HYLINK;
  {$EXTERNALSYM PF_APPLETALK}
  PF_APPLETALK  = AF_APPLETALK;
  {$EXTERNALSYM PF_VOICEVIEW}
  PF_VOICEVIEW  = AF_VOICEVIEW;
  {$EXTERNALSYM PF_FIREFOX}
  PF_FIREFOX    = AF_FIREFOX;
  {$EXTERNALSYM PF_UNKNOWN1}
  PF_UNKNOWN1   = AF_UNKNOWN1;
  {$EXTERNALSYM PF_BAN}
  PF_BAN        = AF_BAN;
  {$EXTERNALSYM PF_ATM}
  PF_ATM        = AF_ATM;
  {$EXTERNALSYM PF_INET6}
  PF_INET6      = AF_INET6;
  {$EXTERNALSYM PF_BTH}
  PF_BTH        = AF_BTH;
  {$EXTERNALSYM PF_MAX}
  PF_MAX        = AF_MAX;

  {$EXTERNALSYM SOCK_STREAM}
  SOCK_STREAM    = 1;                     { stream socket }
  {$EXTERNALSYM SOCK_DGRAM}
  SOCK_DGRAM     = 2;                     { datagram socket }
  {$EXTERNALSYM SOCK_RAW}
  SOCK_RAW       = 3;                     { raw-protocol interface }
  {$EXTERNALSYM SOCK_RDM}
  SOCK_RDM       = 4;                     { reliably-delivered message }
  {$EXTERNALSYM SOCK_SEQPACKET}
  SOCK_SEQPACKET = 5;                     { sequenced packet stream }

  { IPPROTO (an enumeration in C) }
  {$EXTERNALSYM IPPROTO_IP}
  IPPROTO_IP       = 0;
  {$EXTERNALSYM IPPROTO_HOPOPTS}
  IPPROTO_HOPOPTS  = 0;                   { IPv6 hop-by-hop options }
  {$EXTERNALSYM IPPROTO_ICMP}
  IPPROTO_ICMP     = 1;
  {$EXTERNALSYM IPPROTO_IGMP}
  IPPROTO_IGMP     = 2;
  {$EXTERNALSYM IPPROTO_GGP}
  IPPROTO_GGP      = 3;
  {$EXTERNALSYM IPPROTO_IPV4}
  IPPROTO_IPV4     = 4;
  {$EXTERNALSYM IPPROTO_ST}
  IPPROTO_ST       = 5;
  {$EXTERNALSYM IPPROTO_TCP}
  IPPROTO_TCP      = 6;
  {$EXTERNALSYM IPPROTO_CBT}
  IPPROTO_CBT      = 7;
  {$EXTERNALSYM IPPROTO_EGP}
  IPPROTO_EGP      = 8;
  {$EXTERNALSYM IPPROTO_IGP}
  IPPROTO_IGP      = 9;
  {$EXTERNALSYM IPPROTO_PUP}
  IPPROTO_PUP      = 12;
  {$EXTERNALSYM IPPROTO_UDP}
  IPPROTO_UDP      = 17;
  {$EXTERNALSYM IPPROTO_IDP}
  IPPROTO_IDP      = 22;
  {$EXTERNALSYM IPPROTO_RDP}
  IPPROTO_RDP      = 27;
  {$EXTERNALSYM IPPROTO_IPV6}
  IPPROTO_IPV6     = 41;                  { IPv6 header }
  {$EXTERNALSYM IPPROTO_ROUTING}
  IPPROTO_ROUTING  = 43;                  { IPv6 routing header }
  {$EXTERNALSYM IPPROTO_FRAGMENT}
  IPPROTO_FRAGMENT = 44;                  { IPv6 fragmentation header }
  {$EXTERNALSYM IPPROTO_ESP}
  IPPROTO_ESP      = 50;                  { encapsulating security payload }
  {$EXTERNALSYM IPPROTO_AH}
  IPPROTO_AH       = 51;                  { authentication header }
  {$EXTERNALSYM IPPROTO_ICMPV6}
  IPPROTO_ICMPV6   = 58;
  {$EXTERNALSYM IPPROTO_NONE}
  IPPROTO_NONE     = 59;                  { IPv6 no next header }
  {$EXTERNALSYM IPPROTO_DSTOPTS}
  IPPROTO_DSTOPTS  = 60;                  { IPv6 destination options }
  {$EXTERNALSYM IPPROTO_ND}
  IPPROTO_ND       = 77;
  {$EXTERNALSYM IPPROTO_ICLFXBM}
  IPPROTO_ICLFXBM  = 78;
  {$EXTERNALSYM IPPROTO_PIM}
  IPPROTO_PIM      = 103;
  {$EXTERNALSYM IPPROTO_PGM}
  IPPROTO_PGM      = 113;
  {$EXTERNALSYM IPPROTO_L2TP}
  IPPROTO_L2TP     = 115;
  {$EXTERNALSYM IPPROTO_SCTP}
  IPPROTO_SCTP     = 132;
  {$EXTERNALSYM IPPROTO_RAW}
  IPPROTO_RAW      = 255;
  {$EXTERNALSYM IPPROTO_MAX}
  IPPROTO_MAX      = 256;

  {$EXTERNALSYM IPPORT_TCPMUX}
  IPPORT_TCPMUX         = 1;
  {$EXTERNALSYM IPPORT_ECHO}
  IPPORT_ECHO           = 7;
  {$EXTERNALSYM IPPORT_DISCARD}
  IPPORT_DISCARD        = 9;
  {$EXTERNALSYM IPPORT_SYSTAT}
  IPPORT_SYSTAT         = 11;
  {$EXTERNALSYM IPPORT_DAYTIME}
  IPPORT_DAYTIME        = 13;
  {$EXTERNALSYM IPPORT_NETSTAT}
  IPPORT_NETSTAT        = 15;
  {$EXTERNALSYM IPPORT_QOTD}
  IPPORT_QOTD           = 17;
  {$EXTERNALSYM IPPORT_MSP}
  IPPORT_MSP            = 18;
  {$EXTERNALSYM IPPORT_CHARGEN}
  IPPORT_CHARGEN        = 19;
  {$EXTERNALSYM IPPORT_FTP_DATA}
  IPPORT_FTP_DATA       = 20;
  {$EXTERNALSYM IPPORT_FTP}
  IPPORT_FTP            = 21;
  {$EXTERNALSYM IPPORT_TELNET}
  IPPORT_TELNET         = 23;
  {$EXTERNALSYM IPPORT_SMTP}
  IPPORT_SMTP           = 25;
  {$EXTERNALSYM IPPORT_TIMESERVER}
  IPPORT_TIMESERVER     = 37;
  {$EXTERNALSYM IPPORT_NAMESERVER}
  IPPORT_NAMESERVER     = 42;
  {$EXTERNALSYM IPPORT_WHOIS}
  IPPORT_WHOIS          = 43;
  {$EXTERNALSYM IPPORT_MTP}
  IPPORT_MTP            = 57;
  {$EXTERNALSYM IPPORT_TFTP}
  IPPORT_TFTP           = 69;
  {$EXTERNALSYM IPPORT_RJE}
  IPPORT_RJE            = 77;
  {$EXTERNALSYM IPPORT_FINGER}
  IPPORT_FINGER         = 79;
  {$EXTERNALSYM IPPORT_TTYLINK}
  IPPORT_TTYLINK        = 87;
  {$EXTERNALSYM IPPORT_SUPDUP}
  IPPORT_SUPDUP         = 95;
  {$EXTERNALSYM IPPORT_POP3}
  IPPORT_POP3           = 110;
  {$EXTERNALSYM IPPORT_NTP}
  IPPORT_NTP            = 123;
  {$EXTERNALSYM IPPORT_EPMAP}
  IPPORT_EPMAP          = 135;
  {$EXTERNALSYM IPPORT_NETBIOS_NS}
  IPPORT_NETBIOS_NS     = 137;
  {$EXTERNALSYM IPPORT_NETBIOS_DGM}
  IPPORT_NETBIOS_DGM    = 138;
  {$EXTERNALSYM IPPORT_NETBIOS_SSN}
  IPPORT_NETBIOS_SSN    = 139;
  {$EXTERNALSYM IPPORT_IMAP}
  IPPORT_IMAP           = 143;
  {$EXTERNALSYM IPPORT_SNMP}
  IPPORT_SNMP           = 161;
  {$EXTERNALSYM IPPORT_SNMP_TRAP}
  IPPORT_SNMP_TRAP      = 162;
  {$EXTERNALSYM IPPORT_IMAP3}
  IPPORT_IMAP3          = 220;
  {$EXTERNALSYM IPPORT_LDAP}
  IPPORT_LDAP           = 389;
  {$EXTERNALSYM IPPORT_HTTPS}
  IPPORT_HTTPS          = 443;
  {$EXTERNALSYM IPPORT_MICROSOFT_DS}
  IPPORT_MICROSOFT_DS   = 445;
  {$EXTERNALSYM IPPORT_EXECSERVER}
  IPPORT_EXECSERVER     = 512;
  {$EXTERNALSYM IPPORT_LOGINSERVER}
  IPPORT_LOGINSERVER    = 513;
  {$EXTERNALSYM IPPORT_CMDSERVER}
  IPPORT_CMDSERVER      = 514;
  {$EXTERNALSYM IPPORT_EFSSERVER}
  IPPORT_EFSSERVER      = 520;
  {$EXTERNALSYM IPPORT_BIFFUDP}
  IPPORT_BIFFUDP        = 512;
  {$EXTERNALSYM IPPORT_WHOSERVER}
  IPPORT_WHOSERVER      = 513;
  {$EXTERNALSYM IPPORT_ROUTESERVER}
  IPPORT_ROUTESERVER    = 520;
  {$EXTERNALSYM IPPORT_RESERVED}
  IPPORT_RESERVED       = 1024;
  {$EXTERNALSYM IPPORT_REGISTERED_MIN}
  IPPORT_REGISTERED_MIN = IPPORT_RESERVED;
  {$EXTERNALSYM IPPORT_REGISTERED_MAX}
  IPPORT_REGISTERED_MAX = $BFFF;
  {$EXTERNALSYM IPPORT_DYNAMIC_MIN}
  IPPORT_DYNAMIC_MIN    = $C000;
  {$EXTERNALSYM IPPORT_DYNAMIC_MAX}
  IPPORT_DYNAMIC_MAX    = $FFFF;

  { IPv4 addresses in host byte order (htonl converts them) }
  {$EXTERNALSYM INADDR_ANY}
  INADDR_ANY       = u_long($00000000);
  {$EXTERNALSYM INADDR_LOOPBACK}
  INADDR_LOOPBACK  = $7F000001;
  {$EXTERNALSYM INADDR_BROADCAST}
  INADDR_BROADCAST = u_long($FFFFFFFF);
  {$EXTERNALSYM INADDR_NONE}
  INADDR_NONE      = $FFFFFFFF;
  {$EXTERNALSYM ADDR_ANY}
  ADDR_ANY         = INADDR_ANY;

  { Buffer sizes for inet_ntop / InetNtop, including the terminating null }
  {$EXTERNALSYM INET_ADDRSTRLEN}
  INET_ADDRSTRLEN  = 22;
  {$EXTERNALSYM INET6_ADDRSTRLEN}
  INET6_ADDRSTRLEN = 65;

  { sockaddr_storage paddings }
  {$EXTERNALSYM _SS_MAXSIZE}
  _SS_MAXSIZE   = 128;
  {$EXTERNALSYM _SS_ALIGNSIZE}
  _SS_ALIGNSIZE = SizeOf(Int64);
  {$EXTERNALSYM _SS_PAD1SIZE}
  _SS_PAD1SIZE  = _SS_ALIGNSIZE - SizeOf(Word);
  {$EXTERNALSYM _SS_PAD2SIZE}
  _SS_PAD2SIZE  = _SS_MAXSIZE - (SizeOf(Word) + _SS_PAD1SIZE + _SS_ALIGNSIZE);

{ ====== Addresses (inaddr.h, in6addr.h, ws2def.h, ws2ipdef.h) ============= }

type
  { The members of in_addr.S_un (anonymous structures in C) }
  in_addr_S_un_b = record
    s_b1, s_b2, s_b3, s_b4: u_char;
  end;
  in_addr_S_un_w = record
    s_w1, s_w2: u_short;
  end;
  in_addr_S_un = record
    case Integer of
      0: (S_un_b: in_addr_S_un_b);
      1: (S_un_w: in_addr_S_un_w);
      2: (S_addr: u_long);
  end;
  SunB = in_addr_S_un_b;
  SunW = in_addr_S_un_w;

  { An IPv4 address, in network byte order. }
  {$EXTERNALSYM PIN_ADDR}
  PIN_ADDR = ^in_addr;
  {$EXTERNALSYM in_addr}
  in_addr = record
    case Integer of
      0: (S_un: in_addr_S_un);
      { the members of S_un: S_addr is the s_addr macro of C }
      1: (S_addr: u_long);
      2: (S_un_b: in_addr_S_un_b);
      3: (S_un_w: in_addr_S_un_w);
  end;
  TInAddr = in_addr;
  PInAddr = PIN_ADDR;
  {$EXTERNALSYM LPIN_ADDR}
  LPIN_ADDR = PIN_ADDR;

  { The member u of in6_addr (an anonymous union in C) }
  in6_addr_u = record
    case Integer of
      0: (Byte: array[0..15] of u_char);
      1: (Word: array[0..7] of u_short);
  end;

  { An IPv6 address, in network byte order. }
  {$EXTERNALSYM PIN6_ADDR}
  PIN6_ADDR = ^in6_addr;
  {$EXTERNALSYM in6_addr}
  in6_addr = record
    case Integer of
      0: (u: in6_addr_u);
      { the macros s6_addr and s6_bytes (u.Byte) and s6_words (u.Word) }
      1: (s6_addr: array[0..15] of u_char);
      2: (s6_bytes: array[0..15] of u_char);
      3: (s6_words: array[0..7] of u_short);
  end;
  TIn6Addr = in6_addr;
  PIn6Addr = PIN6_ADDR;
  {$EXTERNALSYM LPIN6_ADDR}
  LPIN6_ADDR = PIN6_ADDR;
  {$EXTERNALSYM in_addr6}
  in_addr6 = in6_addr;

  { The generic socket address: functions take a PSockAddr and a length, and
    the address is a sockaddr_in, sockaddr_in6 or sockaddr_storage. }
  {$EXTERNALSYM PSOCKADDR}
  PSockAddr = ^sockaddr;
  {$EXTERNALSYM sockaddr}
  sockaddr = record
    sa_family: ADDRESS_FAMILY;
    sa_data: array[0..13] of AnsiChar;
  end;
  TSockAddr = sockaddr;
  {$EXTERNALSYM LPSOCKADDR}
  LPSOCKADDR = PSockAddr;
  PPSockAddr = ^PSockAddr;

  PSockAddrIn = ^sockaddr_in;
  {$EXTERNALSYM sockaddr_in}
  sockaddr_in = record
    sin_family: ADDRESS_FAMILY;
    sin_port: u_short;                    { network byte order }
    sin_addr: in_addr;
    sin_zero: array[0..7] of AnsiChar;
  end;
  TSockAddrIn = sockaddr_in;
  {$EXTERNALSYM PSOCKADDR_IN}
  PSOCKADDR_IN = PSockAddrIn;
  {$EXTERNALSYM LPSOCKADDR_IN}
  LPSOCKADDR_IN = PSockAddrIn;

  PSockAddrIn6 = ^sockaddr_in6;
  {$EXTERNALSYM sockaddr_in6}
  sockaddr_in6 = record
    sin6_family: ADDRESS_FAMILY;
    sin6_port: u_short;                   { network byte order }
    sin6_flowinfo: u_long;
    sin6_addr: in6_addr;
    sin6_scope_id: u_long;                { union with sin6_scope_struct in C }
  end;
  TSockAddrIn6 = sockaddr_in6;
  {$EXTERNALSYM PSOCKADDR_IN6}
  PSOCKADDR_IN6 = PSockAddrIn6;
  {$EXTERNALSYM LPSOCKADDR_IN6}
  LPSOCKADDR_IN6 = PSockAddrIn6;
  {$EXTERNALSYM SOCKADDR_IN6_LH}
  SOCKADDR_IN6_LH = sockaddr_in6;
  {$EXTERNALSYM PSOCKADDR_IN6_LH}
  PSOCKADDR_IN6_LH = PSockAddrIn6;
  {$EXTERNALSYM LPSOCKADDR_IN6_LH}
  LPSOCKADDR_IN6_LH = PSockAddrIn6;

  { Space for any socket address (128 bytes, 8-byte aligned) }
  PSockAddrStorage = ^sockaddr_storage;
  {$EXTERNALSYM sockaddr_storage}
  sockaddr_storage = record
    ss_family: ADDRESS_FAMILY;
    __ss_pad1: array[0.._SS_PAD1SIZE - 1] of AnsiChar;
    __ss_align: Int64;
    __ss_pad2: array[0.._SS_PAD2SIZE - 1] of AnsiChar;
  end;
  TSockAddrStorage = sockaddr_storage;
  {$EXTERNALSYM PSOCKADDR_STORAGE}
  PSOCKADDR_STORAGE = PSockAddrStorage;
  {$EXTERNALSYM LPSOCKADDR_STORAGE}
  LPSOCKADDR_STORAGE = PSockAddrStorage;
  {$EXTERNALSYM SOCKADDR_STORAGE_LH}
  SOCKADDR_STORAGE_LH = sockaddr_storage;
  {$EXTERNALSYM PSOCKADDR_STORAGE_LH}
  PSOCKADDR_STORAGE_LH = PSockAddrStorage;
  {$EXTERNALSYM LPSOCKADDR_STORAGE_LH}
  LPSOCKADDR_STORAGE_LH = PSockAddrStorage;

  { An IPv4 or IPv6 address (used by the IP Helper API) }
  {$EXTERNALSYM PSOCKADDR_INET}
  PSOCKADDR_INET = ^_SOCKADDR_INET;
  {$EXTERNALSYM _SOCKADDR_INET}
  _SOCKADDR_INET = record
    case Integer of
      0: (Ipv4: sockaddr_in);
      1: (Ipv6: sockaddr_in6);
      2: (si_family: ADDRESS_FAMILY);
  end;
  {$EXTERNALSYM SOCKADDR_INET}
  SOCKADDR_INET = _SOCKADDR_INET;
  TSockAddrInet = _SOCKADDR_INET;
  PSockAddrInet = PSOCKADDR_INET;

  {$EXTERNALSYM PSOCKET_ADDRESS}
  PSOCKET_ADDRESS = ^_SOCKET_ADDRESS;
  {$EXTERNALSYM _SOCKET_ADDRESS}
  _SOCKET_ADDRESS = record
    lpSockaddr: PSockAddr;
    iSockaddrLength: Integer;
  end;
  {$EXTERNALSYM SOCKET_ADDRESS}
  SOCKET_ADDRESS = _SOCKET_ADDRESS;
  TSocketAddress = _SOCKET_ADDRESS;
  PSocketAddress = PSOCKET_ADDRESS;
  {$EXTERNALSYM LPSOCKET_ADDRESS}
  LPSOCKET_ADDRESS = PSOCKET_ADDRESS;

  { Returned by SIO_ADDRESS_LIST_QUERY; Address has iAddressCount elements }
  {$EXTERNALSYM PSOCKET_ADDRESS_LIST}
  PSOCKET_ADDRESS_LIST = ^_SOCKET_ADDRESS_LIST;
  {$EXTERNALSYM _SOCKET_ADDRESS_LIST}
  _SOCKET_ADDRESS_LIST = record
    iAddressCount: Integer;
    Address: array[0..0] of SOCKET_ADDRESS;
  end;
  {$EXTERNALSYM SOCKET_ADDRESS_LIST}
  SOCKET_ADDRESS_LIST = _SOCKET_ADDRESS_LIST;
  TSocketAddressList = _SOCKET_ADDRESS_LIST;
  PSocketAddressList = PSOCKET_ADDRESS_LIST;
  {$EXTERNALSYM LPSOCKET_ADDRESS_LIST}
  LPSOCKET_ADDRESS_LIST = PSOCKET_ADDRESS_LIST;

  { SIO_GET_INTERFACE_LIST returns an array of INTERFACE_INFO }
  {$EXTERNALSYM sockaddr_in6_old}
  sockaddr_in6_old = record
    sin6_family: Smallint;
    sin6_port: u_short;
    sin6_flowinfo: u_long;
    sin6_addr: in6_addr;
  end;
  {$EXTERNALSYM sockaddr_gen}
  sockaddr_gen = record
    case Integer of
      0: (Address: sockaddr);
      1: (AddressIn: sockaddr_in);
      2: (AddressIn6: sockaddr_in6_old);
  end;
  TSockAddrGen = sockaddr_gen;

  PInterfaceInfo = ^TInterfaceInfo;
  {$EXTERNALSYM _INTERFACE_INFO}
  _INTERFACE_INFO = record
    iiFlags: u_long;                      { IFF_* }
    iiAddress: sockaddr_gen;
    iiBroadcastAddress: sockaddr_gen;
    iiNetmask: sockaddr_gen;
  end;
  {$EXTERNALSYM INTERFACE_INFO}
  INTERFACE_INFO = _INTERFACE_INFO;
  TInterfaceInfo = _INTERFACE_INFO;
  {$EXTERNALSYM LPINTERFACE_INFO}
  LPINTERFACE_INFO = PInterfaceInfo;

  PInterfaceInfoEx = ^TInterfaceInfoEx;
  {$EXTERNALSYM _INTERFACE_INFO_EX}
  _INTERFACE_INFO_EX = record
    iiFlags: u_long;                      { IFF_* }
    iiAddress: SOCKET_ADDRESS;
    iiBroadcastAddress: SOCKET_ADDRESS;
    iiNetmask: SOCKET_ADDRESS;
  end;
  {$EXTERNALSYM INTERFACE_INFO_EX}
  INTERFACE_INFO_EX = _INTERFACE_INFO_EX;
  TInterfaceInfoEx = _INTERFACE_INFO_EX;
  {$EXTERNALSYM LPINTERFACE_INFO_EX}
  LPINTERFACE_INFO_EX = PInterfaceInfoEx;

  { IP_ADD_MEMBERSHIP / IP_DROP_MEMBERSHIP }
  {$EXTERNALSYM PIP_MREQ}
  PIP_MREQ = ^ip_mreq;
  {$EXTERNALSYM ip_mreq}
  ip_mreq = record
    imr_multiaddr: in_addr;               { multicast group address }
    imr_interface: in_addr;               { local interface address }
  end;
  TIPMreq = ip_mreq;
  PIPMreq = PIP_MREQ;

  { IP_ADD_SOURCE_MEMBERSHIP, IP_BLOCK_SOURCE ... }
  {$EXTERNALSYM PIP_MREQ_SOURCE}
  PIP_MREQ_SOURCE = ^ip_mreq_source;
  {$EXTERNALSYM ip_mreq_source}
  ip_mreq_source = record
    imr_multiaddr: in_addr;
    imr_sourceaddr: in_addr;
    imr_interface: in_addr;
  end;
  TIPMreqSource = ip_mreq_source;
  PIPMreqSource = PIP_MREQ_SOURCE;

  { IPV6_JOIN_GROUP / IPV6_LEAVE_GROUP }
  {$EXTERNALSYM PIPV6_MREQ}
  PIPV6_MREQ = ^ipv6_mreq;
  {$EXTERNALSYM ipv6_mreq}
  ipv6_mreq = record
    ipv6mr_multiaddr: in6_addr;
    ipv6mr_interface: ULONG;              { interface index }
  end;
  TIPv6Mreq = ipv6_mreq;
  PIPv6Mreq = PIPV6_MREQ;

  { Control data of IP_PKTINFO / IPV6_PKTINFO (WSARecvMsg) }
  {$EXTERNALSYM PIN_PKTINFO}
  PIN_PKTINFO = ^in_pktinfo;
  {$EXTERNALSYM in_pktinfo}
  in_pktinfo = record
    ipi_addr: in_addr;
    ipi_ifindex: ULONG;
  end;
  TInPktInfo = in_pktinfo;
  PInPktInfo = PIN_PKTINFO;

  {$EXTERNALSYM PIN6_PKTINFO}
  PIN6_PKTINFO = ^in6_pktinfo;
  {$EXTERNALSYM in6_pktinfo}
  in6_pktinfo = record
    ipi6_addr: in6_addr;
    ipi6_ifindex: ULONG;
  end;
  TIn6PktInfo = in6_pktinfo;
  PIn6PktInfo = PIN6_PKTINFO;

const
  { The unspecified (::) and loopback (::1) IPv6 addresses. In C these are
    data exports of ws2_32.dll; here they are typed constants. }
  {$EXTERNALSYM in6addr_any}
  in6addr_any: in6_addr = (s6_bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
  {$EXTERNALSYM in6addr_loopback}
  in6addr_loopback: in6_addr = (s6_bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1));

{ ====== Socket options =================================================== }

const
  { Level for getsockopt / setsockopt that applies to the socket itself }
  {$EXTERNALSYM SOL_SOCKET}
  SOL_SOCKET = $FFFF;
  {$EXTERNALSYM SOL_IP}
  SOL_IP     = SOL_SOCKET - 4;
  {$EXTERNALSYM SOL_IPV6}
  SOL_IPV6   = SOL_SOCKET - 5;

  { SOL_SOCKET options }
  {$EXTERNALSYM SO_DEBUG}
  SO_DEBUG               = $0001;         { turn on debugging info recording }
  {$EXTERNALSYM SO_ACCEPTCONN}
  SO_ACCEPTCONN          = $0002;         { socket has had listen() }
  {$EXTERNALSYM SO_REUSEADDR}
  SO_REUSEADDR           = $0004;         { allow local address reuse }
  {$EXTERNALSYM SO_KEEPALIVE}
  SO_KEEPALIVE           = $0008;         { keep connections alive }
  {$EXTERNALSYM SO_DONTROUTE}
  SO_DONTROUTE           = $0010;         { just use interface addresses }
  {$EXTERNALSYM SO_BROADCAST}
  SO_BROADCAST           = $0020;         { permit sending of broadcast msgs }
  {$EXTERNALSYM SO_USELOOPBACK}
  SO_USELOOPBACK         = $0040;         { bypass hardware when possible }
  {$EXTERNALSYM SO_LINGER}
  SO_LINGER              = $0080;         { linger on close if data present }
  {$EXTERNALSYM SO_OOBINLINE}
  SO_OOBINLINE           = $0100;         { leave received OOB data in line }
  {$EXTERNALSYM SO_DONTLINGER}
  SO_DONTLINGER          = Integer(not SO_LINGER);
  {$EXTERNALSYM SO_EXCLUSIVEADDRUSE}
  SO_EXCLUSIVEADDRUSE    = Integer(not SO_REUSEADDR); { disallow local address reuse }
  {$EXTERNALSYM SO_SNDBUF}
  SO_SNDBUF              = $1001;         { send buffer size }
  {$EXTERNALSYM SO_RCVBUF}
  SO_RCVBUF              = $1002;         { receive buffer size }
  {$EXTERNALSYM SO_SNDLOWAT}
  SO_SNDLOWAT            = $1003;         { send low-water mark }
  {$EXTERNALSYM SO_RCVLOWAT}
  SO_RCVLOWAT            = $1004;         { receive low-water mark }
  {$EXTERNALSYM SO_SNDTIMEO}
  SO_SNDTIMEO            = $1005;         { send timeout (DWORD, ms) }
  {$EXTERNALSYM SO_RCVTIMEO}
  SO_RCVTIMEO            = $1006;         { receive timeout (DWORD, ms) }
  {$EXTERNALSYM SO_ERROR}
  SO_ERROR               = $1007;         { get error status and clear }
  {$EXTERNALSYM SO_TYPE}
  SO_TYPE                = $1008;         { get socket type }
  {$EXTERNALSYM SO_BSP_STATE}
  SO_BSP_STATE           = $1009;         { get socket 5-tuple state }
  {$EXTERNALSYM SO_GROUP_ID}
  SO_GROUP_ID            = $2001;         { ID of a socket group }
  {$EXTERNALSYM SO_GROUP_PRIORITY}
  SO_GROUP_PRIORITY      = $2002;         { the relative priority within a group }
  {$EXTERNALSYM SO_MAX_MSG_SIZE}
  SO_MAX_MSG_SIZE        = $2003;         { maximum message size }
  {$EXTERNALSYM SO_PROTOCOL_INFOA}
  SO_PROTOCOL_INFOA      = $2004;         { WSAPROTOCOL_INFOA structure }
  {$EXTERNALSYM SO_PROTOCOL_INFOW}
  SO_PROTOCOL_INFOW      = $2005;         { WSAPROTOCOL_INFOW structure }
  {$EXTERNALSYM SO_PROTOCOL_INFO}
  SO_PROTOCOL_INFO       = SO_PROTOCOL_INFOA;
  {$EXTERNALSYM PVD_CONFIG}
  PVD_CONFIG             = $3001;         { configuration info for service provider }
  {$EXTERNALSYM SO_CONDITIONAL_ACCEPT}
  SO_CONDITIONAL_ACCEPT  = $3002;         { WSAAccept's condition function acks the connection }
  {$EXTERNALSYM SO_PAUSE_ACCEPT}
  SO_PAUSE_ACCEPT        = $3003;         { pause accepting new connections }
  {$EXTERNALSYM SO_COMPARTMENT_ID}
  SO_COMPARTMENT_ID      = $3004;         { get/set the compartment for a socket }
  {$EXTERNALSYM SO_RANDOMIZE_PORT}
  SO_RANDOMIZE_PORT      = $3005;         { randomize assignment of wildcard ports }
  {$EXTERNALSYM SO_PORT_SCALABILITY}
  SO_PORT_SCALABILITY    = $3006;         { enable port scalability }
  {$EXTERNALSYM SO_REUSE_UNICASTPORT}
  SO_REUSE_UNICASTPORT   = $3007;         { defer ephemeral port allocation }
  {$EXTERNALSYM SO_REUSE_MULTICASTPORT}
  SO_REUSE_MULTICASTPORT = $3008;         { enable port reuse, disable unicast reception }

  { SOL_SOCKET options of mswsock.h }
  {$EXTERNALSYM SO_CONNDATA}
  SO_CONNDATA               = $7000;
  {$EXTERNALSYM SO_CONNOPT}
  SO_CONNOPT                = $7001;
  {$EXTERNALSYM SO_DISCDATA}
  SO_DISCDATA               = $7002;
  {$EXTERNALSYM SO_DISCOPT}
  SO_DISCOPT                = $7003;
  {$EXTERNALSYM SO_CONNDATALEN}
  SO_CONNDATALEN            = $7004;
  {$EXTERNALSYM SO_CONNOPTLEN}
  SO_CONNOPTLEN             = $7005;
  {$EXTERNALSYM SO_DISCDATALEN}
  SO_DISCDATALEN            = $7006;
  {$EXTERNALSYM SO_DISCOPTLEN}
  SO_DISCOPTLEN             = $7007;
  {$EXTERNALSYM SO_OPENTYPE}
  SO_OPENTYPE               = $7008;
  {$EXTERNALSYM SO_SYNCHRONOUS_ALERT}
  SO_SYNCHRONOUS_ALERT      = $10;
  {$EXTERNALSYM SO_SYNCHRONOUS_NONALERT}
  SO_SYNCHRONOUS_NONALERT   = $20;
  {$EXTERNALSYM SO_MAXDG}
  SO_MAXDG                  = $7009;
  {$EXTERNALSYM SO_MAXPATHDG}
  SO_MAXPATHDG              = $700A;
  {$EXTERNALSYM SO_UPDATE_ACCEPT_CONTEXT}
  SO_UPDATE_ACCEPT_CONTEXT  = $700B;      { after AcceptEx }
  {$EXTERNALSYM SO_CONNECT_TIME}
  SO_CONNECT_TIME           = $700C;
  {$EXTERNALSYM SO_UPDATE_CONNECT_CONTEXT}
  SO_UPDATE_CONNECT_CONTEXT = $7010;      { after ConnectEx }

  { IPPROTO_TCP options }
  {$EXTERNALSYM TCP_NODELAY}
  TCP_NODELAY                    = $0001;
  {$EXTERNALSYM TCP_EXPEDITED_1122}
  TCP_EXPEDITED_1122             = $0002;
  {$EXTERNALSYM TCP_KEEPALIVE}
  TCP_KEEPALIVE                  = 3;
  {$EXTERNALSYM TCP_MAXSEG}
  TCP_MAXSEG                     = 4;
  {$EXTERNALSYM TCP_MAXRT}
  TCP_MAXRT                      = 5;
  {$EXTERNALSYM TCP_STDURG}
  TCP_STDURG                     = 6;
  {$EXTERNALSYM TCP_NOURG}
  TCP_NOURG                      = 7;
  {$EXTERNALSYM TCP_ATMARK}
  TCP_ATMARK                     = 8;
  {$EXTERNALSYM TCP_NOSYNRETRIES}
  TCP_NOSYNRETRIES               = 9;
  {$EXTERNALSYM TCP_TIMESTAMPS}
  TCP_TIMESTAMPS                 = 10;
  {$EXTERNALSYM TCP_OFFLOAD_PREFERENCE}
  TCP_OFFLOAD_PREFERENCE         = 11;
  {$EXTERNALSYM TCP_CONGESTION_ALGORITHM}
  TCP_CONGESTION_ALGORITHM       = 12;
  {$EXTERNALSYM TCP_DELAY_FIN_ACK}
  TCP_DELAY_FIN_ACK              = 13;
  {$EXTERNALSYM TCP_MAXRTMS}
  TCP_MAXRTMS                    = 14;
  {$EXTERNALSYM TCP_FASTOPEN}
  TCP_FASTOPEN                   = 15;
  {$EXTERNALSYM TCP_KEEPCNT}
  TCP_KEEPCNT                    = 16;
  {$EXTERNALSYM TCP_KEEPIDLE}
  TCP_KEEPIDLE                   = TCP_KEEPALIVE;
  {$EXTERNALSYM TCP_KEEPINTVL}
  TCP_KEEPINTVL                  = 17;
  {$EXTERNALSYM TCP_FAIL_CONNECT_ON_ICMP_ERROR}
  TCP_FAIL_CONNECT_ON_ICMP_ERROR = 18;

  { IPPROTO_UDP options }
  {$EXTERNALSYM UDP_NOCHECKSUM}
  UDP_NOCHECKSUM        = 1;
  {$EXTERNALSYM UDP_CHECKSUM_COVERAGE}
  UDP_CHECKSUM_COVERAGE = 20;

  { IPPROTO_IP options }
  {$EXTERNALSYM IP_OPTIONS}
  IP_OPTIONS                = 1;          { set/get IP options }
  {$EXTERNALSYM IP_HDRINCL}
  IP_HDRINCL                = 2;          { header is included with data }
  {$EXTERNALSYM IP_TOS}
  IP_TOS                    = 3;          { IP type of service }
  {$EXTERNALSYM IP_TTL}
  IP_TTL                    = 4;          { IP TTL (hop limit) }
  {$EXTERNALSYM IP_MULTICAST_IF}
  IP_MULTICAST_IF           = 9;          { IP multicast interface }
  {$EXTERNALSYM IP_MULTICAST_TTL}
  IP_MULTICAST_TTL          = 10;         { IP multicast TTL (hop limit) }
  {$EXTERNALSYM IP_MULTICAST_LOOP}
  IP_MULTICAST_LOOP         = 11;         { IP multicast loopback }
  {$EXTERNALSYM IP_ADD_MEMBERSHIP}
  IP_ADD_MEMBERSHIP         = 12;         { add an IP group membership (ip_mreq) }
  {$EXTERNALSYM IP_DROP_MEMBERSHIP}
  IP_DROP_MEMBERSHIP        = 13;         { drop an IP group membership (ip_mreq) }
  {$EXTERNALSYM IP_DONTFRAGMENT}
  IP_DONTFRAGMENT           = 14;         { don't fragment IP datagrams }
  {$EXTERNALSYM IP_ADD_SOURCE_MEMBERSHIP}
  IP_ADD_SOURCE_MEMBERSHIP  = 15;         { join IP group/source }
  {$EXTERNALSYM IP_DROP_SOURCE_MEMBERSHIP}
  IP_DROP_SOURCE_MEMBERSHIP = 16;         { leave IP group/source }
  {$EXTERNALSYM IP_BLOCK_SOURCE}
  IP_BLOCK_SOURCE           = 17;         { block IP group/source }
  {$EXTERNALSYM IP_UNBLOCK_SOURCE}
  IP_UNBLOCK_SOURCE         = 18;         { unblock IP group/source }
  {$EXTERNALSYM IP_PKTINFO}
  IP_PKTINFO                = 19;         { receive packet information }
  {$EXTERNALSYM IP_HOPLIMIT}
  IP_HOPLIMIT               = 21;         { receive packet hop limit }
  {$EXTERNALSYM IP_RECVTTL}
  IP_RECVTTL                = 21;         { receive packet time to live }
  {$EXTERNALSYM IP_RECEIVE_BROADCAST}
  IP_RECEIVE_BROADCAST      = 22;         { allow/block broadcast reception }
  {$EXTERNALSYM IP_RECVIF}
  IP_RECVIF                 = 24;         { receive arrival interface }
  {$EXTERNALSYM IP_RECVDSTADDR}
  IP_RECVDSTADDR            = 25;         { receive destination address }
  {$EXTERNALSYM IP_UNICAST_IF}
  IP_UNICAST_IF             = 31;         { IP unicast interface }
  {$EXTERNALSYM IP_TCLASS}
  IP_TCLASS                 = 39;         { packet traffic class }
  {$EXTERNALSYM IP_RECVTCLASS}
  IP_RECVTCLASS             = 40;         { receive packet traffic class }
  {$EXTERNALSYM IP_RECVTOS}
  IP_RECVTOS                = 40;         { receive packet type of service }
  {$EXTERNALSYM IP_MTU_DISCOVER}
  IP_MTU_DISCOVER           = 71;         { set/get path MTU discover state }
  {$EXTERNALSYM IP_MTU}
  IP_MTU                    = 73;         { get path MTU }

  { IPPROTO_IPV6 options }
  {$EXTERNALSYM IPV6_HOPOPTS}
  IPV6_HOPOPTS          = 1;              { set/get IPv6 hop-by-hop options }
  {$EXTERNALSYM IPV6_HDRINCL}
  IPV6_HDRINCL          = 2;              { header is included with data }
  {$EXTERNALSYM IPV6_UNICAST_HOPS}
  IPV6_UNICAST_HOPS     = 4;              { IP unicast hop limit }
  {$EXTERNALSYM IPV6_MULTICAST_IF}
  IPV6_MULTICAST_IF     = 9;              { IP multicast interface }
  {$EXTERNALSYM IPV6_MULTICAST_HOPS}
  IPV6_MULTICAST_HOPS   = 10;             { IP multicast hop limit }
  {$EXTERNALSYM IPV6_MULTICAST_LOOP}
  IPV6_MULTICAST_LOOP   = 11;             { IP multicast loopback }
  {$EXTERNALSYM IPV6_ADD_MEMBERSHIP}
  IPV6_ADD_MEMBERSHIP   = 12;             { add an IP group membership (ipv6_mreq) }
  {$EXTERNALSYM IPV6_JOIN_GROUP}
  IPV6_JOIN_GROUP       = IPV6_ADD_MEMBERSHIP;
  {$EXTERNALSYM IPV6_DROP_MEMBERSHIP}
  IPV6_DROP_MEMBERSHIP  = 13;             { drop an IP group membership (ipv6_mreq) }
  {$EXTERNALSYM IPV6_LEAVE_GROUP}
  IPV6_LEAVE_GROUP      = IPV6_DROP_MEMBERSHIP;
  {$EXTERNALSYM IPV6_DONTFRAG}
  IPV6_DONTFRAG         = 14;             { don't fragment IP datagrams }
  {$EXTERNALSYM IPV6_PKTINFO}
  IPV6_PKTINFO          = 19;             { receive packet information }
  {$EXTERNALSYM IPV6_HOPLIMIT}
  IPV6_HOPLIMIT         = 21;             { receive packet hop limit }
  {$EXTERNALSYM IPV6_PROTECTION_LEVEL}
  IPV6_PROTECTION_LEVEL = 23;             { set/get IPv6 protection level }
  {$EXTERNALSYM IPV6_RECVIF}
  IPV6_RECVIF           = 24;             { receive arrival interface }
  {$EXTERNALSYM IPV6_RECVDSTADDR}
  IPV6_RECVDSTADDR      = 25;             { receive destination address }
  {$EXTERNALSYM IPV6_CHECKSUM}
  IPV6_CHECKSUM         = 26;             { offset to checksum for raw IP socket send }
  {$EXTERNALSYM IPV6_V6ONLY}
  IPV6_V6ONLY           = 27;             { treat wildcard bind as AF_INET6-only }
  {$EXTERNALSYM IPV6_UNICAST_IF}
  IPV6_UNICAST_IF       = 31;             { IP unicast interface }
  {$EXTERNALSYM IPV6_RTHDR}
  IPV6_RTHDR            = 32;             { set/get IPv6 routing header }
  {$EXTERNALSYM IPV6_RECVRTHDR}
  IPV6_RECVRTHDR        = 38;             { receive the routing header }
  {$EXTERNALSYM IPV6_TCLASS}
  IPV6_TCLASS           = 39;             { packet traffic class }
  {$EXTERNALSYM IPV6_RECVTCLASS}
  IPV6_RECVTCLASS       = 40;             { receive packet traffic class }
  {$EXTERNALSYM IPV6_MTU_DISCOVER}
  IPV6_MTU_DISCOVER     = 71;             { set/get path MTU discover state }
  {$EXTERNALSYM IPV6_MTU}
  IPV6_MTU              = 72;             { get path MTU }

  { IPV6_PROTECTION_LEVEL values }
  {$EXTERNALSYM PROTECTION_LEVEL_UNRESTRICTED}
  PROTECTION_LEVEL_UNRESTRICTED   = 10;   { for peer-to-peer apps }
  {$EXTERNALSYM PROTECTION_LEVEL_EDGERESTRICTED}
  PROTECTION_LEVEL_EDGERESTRICTED = 20;   { same as unrestricted, except for Teredo }
  {$EXTERNALSYM PROTECTION_LEVEL_RESTRICTED}
  PROTECTION_LEVEL_RESTRICTED     = 30;   { for intranet apps }

  { INTERFACE_INFO.iiFlags }
  {$EXTERNALSYM IFF_UP}
  IFF_UP           = $00000001;           { interface is up }
  {$EXTERNALSYM IFF_BROADCAST}
  IFF_BROADCAST    = $00000002;           { broadcast is supported }
  {$EXTERNALSYM IFF_LOOPBACK}
  IFF_LOOPBACK     = $00000004;           { this is loopback interface }
  {$EXTERNALSYM IFF_POINTTOPOINT}
  IFF_POINTTOPOINT = $00000008;           { this is point-to-point interface }
  {$EXTERNALSYM IFF_MULTICAST}
  IFF_MULTICAST    = $00000010;           { multicast is supported }

  { send / recv flags (and WSAMSG.dwFlags) }
  {$EXTERNALSYM MSG_OOB}
  MSG_OOB            = $1;                { process out-of-band data }
  {$EXTERNALSYM MSG_PEEK}
  MSG_PEEK           = $2;                { peek at incoming message }
  {$EXTERNALSYM MSG_DONTROUTE}
  MSG_DONTROUTE      = $4;                { send without using routing tables }
  {$EXTERNALSYM MSG_WAITALL}
  MSG_WAITALL        = $8;                { do not complete until packet is completely filled }
  {$EXTERNALSYM MSG_PUSH_IMMEDIATE}
  MSG_PUSH_IMMEDIATE = $20;               { do not delay receive request completion }
  {$EXTERNALSYM MSG_PARTIAL}
  MSG_PARTIAL        = $8000;             { partial send or recv for message xport }
  {$EXTERNALSYM MSG_INTERRUPT}
  MSG_INTERRUPT      = $10;               { send/recv in the interrupt context }
  {$EXTERNALSYM MSG_TRUNC}
  MSG_TRUNC          = $0100;
  {$EXTERNALSYM MSG_CTRUNC}
  MSG_CTRUNC         = $0200;
  {$EXTERNALSYM MSG_BCAST}
  MSG_BCAST          = $0400;
  {$EXTERNALSYM MSG_MCAST}
  MSG_MCAST          = $0800;
  {$EXTERNALSYM MSG_ERRQUEUE}
  MSG_ERRQUEUE       = $1000;

  { shutdown }
  {$EXTERNALSYM SD_RECEIVE}
  SD_RECEIVE = $00;
  {$EXTERNALSYM SD_SEND}
  SD_SEND    = $01;
  {$EXTERNALSYM SD_BOTH}
  SD_BOTH    = $02;

{ ====== Network events (WSAAsyncSelect, WSAEventSelect, WSAPoll) ========== }

const
  {$EXTERNALSYM FD_READ_BIT}
  FD_READ_BIT                     = 0;
  {$EXTERNALSYM FD_READ}
  FD_READ                         = 1 shl FD_READ_BIT;
  {$EXTERNALSYM FD_WRITE_BIT}
  FD_WRITE_BIT                    = 1;
  {$EXTERNALSYM FD_WRITE}
  FD_WRITE                        = 1 shl FD_WRITE_BIT;
  {$EXTERNALSYM FD_OOB_BIT}
  FD_OOB_BIT                      = 2;
  {$EXTERNALSYM FD_OOB}
  FD_OOB                          = 1 shl FD_OOB_BIT;
  {$EXTERNALSYM FD_ACCEPT_BIT}
  FD_ACCEPT_BIT                   = 3;
  {$EXTERNALSYM FD_ACCEPT}
  FD_ACCEPT                       = 1 shl FD_ACCEPT_BIT;
  {$EXTERNALSYM FD_CONNECT_BIT}
  FD_CONNECT_BIT                  = 4;
  {$EXTERNALSYM FD_CONNECT}
  FD_CONNECT                      = 1 shl FD_CONNECT_BIT;
  {$EXTERNALSYM FD_CLOSE_BIT}
  FD_CLOSE_BIT                    = 5;
  {$EXTERNALSYM FD_CLOSE}
  FD_CLOSE                        = 1 shl FD_CLOSE_BIT;
  {$EXTERNALSYM FD_QOS_BIT}
  FD_QOS_BIT                      = 6;
  {$EXTERNALSYM FD_QOS}
  FD_QOS                          = 1 shl FD_QOS_BIT;
  {$EXTERNALSYM FD_GROUP_QOS_BIT}
  FD_GROUP_QOS_BIT                = 7;
  {$EXTERNALSYM FD_GROUP_QOS}
  FD_GROUP_QOS                    = 1 shl FD_GROUP_QOS_BIT;
  {$EXTERNALSYM FD_ROUTING_INTERFACE_CHANGE_BIT}
  FD_ROUTING_INTERFACE_CHANGE_BIT = 8;
  {$EXTERNALSYM FD_ROUTING_INTERFACE_CHANGE}
  FD_ROUTING_INTERFACE_CHANGE     = 1 shl FD_ROUTING_INTERFACE_CHANGE_BIT;
  {$EXTERNALSYM FD_ADDRESS_LIST_CHANGE_BIT}
  FD_ADDRESS_LIST_CHANGE_BIT      = 9;
  {$EXTERNALSYM FD_ADDRESS_LIST_CHANGE}
  FD_ADDRESS_LIST_CHANGE          = 1 shl FD_ADDRESS_LIST_CHANGE_BIT;
  {$EXTERNALSYM FD_MAX_EVENTS}
  FD_MAX_EVENTS                   = 10;
  {$EXTERNALSYM FD_ALL_EVENTS}
  FD_ALL_EVENTS                   = (1 shl FD_MAX_EVENTS) - 1;

  { WSAPOLLFD.events / revents }
  {$EXTERNALSYM POLLRDNORM}
  POLLRDNORM = $0100;
  {$EXTERNALSYM POLLRDBAND}
  POLLRDBAND = $0200;
  {$EXTERNALSYM POLLIN}
  POLLIN     = POLLRDNORM or POLLRDBAND;
  {$EXTERNALSYM POLLPRI}
  POLLPRI    = $0400;
  {$EXTERNALSYM POLLWRNORM}
  POLLWRNORM = $0010;
  {$EXTERNALSYM POLLOUT}
  POLLOUT    = POLLWRNORM;
  {$EXTERNALSYM POLLWRBAND}
  POLLWRBAND = $0020;
  {$EXTERNALSYM POLLERR}
  POLLERR    = $0001;
  {$EXTERNALSYM POLLHUP}
  POLLHUP    = $0002;
  {$EXTERNALSYM POLLNVAL}
  POLLNVAL   = $0004;

  { Event objects and overlapped I/O (the Windows values) }
  {$EXTERNALSYM WSA_IO_PENDING}
  WSA_IO_PENDING          = ERROR_IO_PENDING;
  {$EXTERNALSYM WSA_IO_INCOMPLETE}
  WSA_IO_INCOMPLETE       = ERROR_IO_INCOMPLETE;
  {$EXTERNALSYM WSA_INVALID_HANDLE}
  WSA_INVALID_HANDLE      = ERROR_INVALID_HANDLE;
  {$EXTERNALSYM WSA_INVALID_PARAMETER}
  WSA_INVALID_PARAMETER   = ERROR_INVALID_PARAMETER;
  {$EXTERNALSYM WSA_NOT_ENOUGH_MEMORY}
  WSA_NOT_ENOUGH_MEMORY   = ERROR_NOT_ENOUGH_MEMORY;
  {$EXTERNALSYM WSA_OPERATION_ABORTED}
  WSA_OPERATION_ABORTED   = ERROR_OPERATION_ABORTED;
  {$EXTERNALSYM WSA_INVALID_EVENT}
  WSA_INVALID_EVENT       = WSAEVENT(0);
  {$EXTERNALSYM WSA_MAXIMUM_WAIT_EVENTS}
  WSA_MAXIMUM_WAIT_EVENTS = MAXIMUM_WAIT_OBJECTS;
  {$EXTERNALSYM WSA_WAIT_FAILED}
  WSA_WAIT_FAILED         = WAIT_FAILED;
  {$EXTERNALSYM WSA_WAIT_EVENT_0}
  WSA_WAIT_EVENT_0        = WAIT_OBJECT_0;
  {$EXTERNALSYM WSA_WAIT_IO_COMPLETION}
  WSA_WAIT_IO_COMPLETION  = WAIT_IO_COMPLETION;
  {$EXTERNALSYM WSA_WAIT_TIMEOUT}
  WSA_WAIT_TIMEOUT        = WAIT_TIMEOUT;
  {$EXTERNALSYM WSA_INFINITE}
  WSA_INFINITE            = INFINITE;

{ ====== Error codes (winsock2.h, winerror.h, ws2tcpip.h) ================== }

const
  {$EXTERNALSYM WSABASEERR}
  WSABASEERR              = 10000;

  { Windows Sockets definitions of regular Microsoft C error constants }
  {$EXTERNALSYM WSAEINTR}
  WSAEINTR                = WSABASEERR + 4;
  {$EXTERNALSYM WSAEBADF}
  WSAEBADF                = WSABASEERR + 9;
  {$EXTERNALSYM WSAEACCES}
  WSAEACCES               = WSABASEERR + 13;
  {$EXTERNALSYM WSAEFAULT}
  WSAEFAULT               = WSABASEERR + 14;
  {$EXTERNALSYM WSAEINVAL}
  WSAEINVAL               = WSABASEERR + 22;
  {$EXTERNALSYM WSAEMFILE}
  WSAEMFILE               = WSABASEERR + 24;

  { Windows Sockets definitions of regular Berkeley error constants }
  {$EXTERNALSYM WSAEWOULDBLOCK}
  WSAEWOULDBLOCK          = WSABASEERR + 35;
  {$EXTERNALSYM WSAEINPROGRESS}
  WSAEINPROGRESS          = WSABASEERR + 36;
  {$EXTERNALSYM WSAEALREADY}
  WSAEALREADY             = WSABASEERR + 37;
  {$EXTERNALSYM WSAENOTSOCK}
  WSAENOTSOCK             = WSABASEERR + 38;
  {$EXTERNALSYM WSAEDESTADDRREQ}
  WSAEDESTADDRREQ         = WSABASEERR + 39;
  {$EXTERNALSYM WSAEMSGSIZE}
  WSAEMSGSIZE             = WSABASEERR + 40;
  {$EXTERNALSYM WSAEPROTOTYPE}
  WSAEPROTOTYPE           = WSABASEERR + 41;
  {$EXTERNALSYM WSAENOPROTOOPT}
  WSAENOPROTOOPT          = WSABASEERR + 42;
  {$EXTERNALSYM WSAEPROTONOSUPPORT}
  WSAEPROTONOSUPPORT      = WSABASEERR + 43;
  {$EXTERNALSYM WSAESOCKTNOSUPPORT}
  WSAESOCKTNOSUPPORT      = WSABASEERR + 44;
  {$EXTERNALSYM WSAEOPNOTSUPP}
  WSAEOPNOTSUPP           = WSABASEERR + 45;
  {$EXTERNALSYM WSAEPFNOSUPPORT}
  WSAEPFNOSUPPORT         = WSABASEERR + 46;
  {$EXTERNALSYM WSAEAFNOSUPPORT}
  WSAEAFNOSUPPORT         = WSABASEERR + 47;
  {$EXTERNALSYM WSAEADDRINUSE}
  WSAEADDRINUSE           = WSABASEERR + 48;
  {$EXTERNALSYM WSAEADDRNOTAVAIL}
  WSAEADDRNOTAVAIL        = WSABASEERR + 49;
  {$EXTERNALSYM WSAENETDOWN}
  WSAENETDOWN             = WSABASEERR + 50;
  {$EXTERNALSYM WSAENETUNREACH}
  WSAENETUNREACH          = WSABASEERR + 51;
  {$EXTERNALSYM WSAENETRESET}
  WSAENETRESET            = WSABASEERR + 52;
  {$EXTERNALSYM WSAECONNABORTED}
  WSAECONNABORTED         = WSABASEERR + 53;
  {$EXTERNALSYM WSAECONNRESET}
  WSAECONNRESET           = WSABASEERR + 54;
  {$EXTERNALSYM WSAENOBUFS}
  WSAENOBUFS              = WSABASEERR + 55;
  {$EXTERNALSYM WSAEISCONN}
  WSAEISCONN              = WSABASEERR + 56;
  {$EXTERNALSYM WSAENOTCONN}
  WSAENOTCONN             = WSABASEERR + 57;
  {$EXTERNALSYM WSAESHUTDOWN}
  WSAESHUTDOWN            = WSABASEERR + 58;
  {$EXTERNALSYM WSAETOOMANYREFS}
  WSAETOOMANYREFS         = WSABASEERR + 59;
  {$EXTERNALSYM WSAETIMEDOUT}
  WSAETIMEDOUT            = WSABASEERR + 60;
  {$EXTERNALSYM WSAECONNREFUSED}
  WSAECONNREFUSED         = WSABASEERR + 61;
  {$EXTERNALSYM WSAELOOP}
  WSAELOOP                = WSABASEERR + 62;
  {$EXTERNALSYM WSAENAMETOOLONG}
  WSAENAMETOOLONG         = WSABASEERR + 63;
  {$EXTERNALSYM WSAEHOSTDOWN}
  WSAEHOSTDOWN            = WSABASEERR + 64;
  {$EXTERNALSYM WSAEHOSTUNREACH}
  WSAEHOSTUNREACH         = WSABASEERR + 65;
  {$EXTERNALSYM WSAENOTEMPTY}
  WSAENOTEMPTY            = WSABASEERR + 66;
  {$EXTERNALSYM WSAEPROCLIM}
  WSAEPROCLIM             = WSABASEERR + 67;
  {$EXTERNALSYM WSAEUSERS}
  WSAEUSERS               = WSABASEERR + 68;
  {$EXTERNALSYM WSAEDQUOT}
  WSAEDQUOT               = WSABASEERR + 69;
  {$EXTERNALSYM WSAESTALE}
  WSAESTALE               = WSABASEERR + 70;
  {$EXTERNALSYM WSAEREMOTE}
  WSAEREMOTE              = WSABASEERR + 71;

  { Extended Windows Sockets error constant definitions }
  {$EXTERNALSYM WSASYSNOTREADY}
  WSASYSNOTREADY          = WSABASEERR + 91;
  {$EXTERNALSYM WSAVERNOTSUPPORTED}
  WSAVERNOTSUPPORTED      = WSABASEERR + 92;
  {$EXTERNALSYM WSANOTINITIALISED}
  WSANOTINITIALISED       = WSABASEERR + 93;
  {$EXTERNALSYM WSAEDISCON}
  WSAEDISCON              = WSABASEERR + 101;
  {$EXTERNALSYM WSAENOMORE}
  WSAENOMORE              = WSABASEERR + 102;
  {$EXTERNALSYM WSAECANCELLED}
  WSAECANCELLED           = WSABASEERR + 103;
  {$EXTERNALSYM WSAEINVALIDPROCTABLE}
  WSAEINVALIDPROCTABLE    = WSABASEERR + 104;
  {$EXTERNALSYM WSAEINVALIDPROVIDER}
  WSAEINVALIDPROVIDER     = WSABASEERR + 105;
  {$EXTERNALSYM WSAEPROVIDERFAILEDINIT}
  WSAEPROVIDERFAILEDINIT  = WSABASEERR + 106;
  {$EXTERNALSYM WSASYSCALLFAILURE}
  WSASYSCALLFAILURE       = WSABASEERR + 107;
  {$EXTERNALSYM WSASERVICE_NOT_FOUND}
  WSASERVICE_NOT_FOUND    = WSABASEERR + 108;
  {$EXTERNALSYM WSATYPE_NOT_FOUND}
  WSATYPE_NOT_FOUND       = WSABASEERR + 109;
  {$EXTERNALSYM WSA_E_NO_MORE}
  WSA_E_NO_MORE           = WSABASEERR + 110;
  {$EXTERNALSYM WSA_E_CANCELLED}
  WSA_E_CANCELLED         = WSABASEERR + 111;
  {$EXTERNALSYM WSAEREFUSED}
  WSAEREFUSED             = WSABASEERR + 112;

  { Resolver errors (h_errno in BSD) }
  {$EXTERNALSYM WSAHOST_NOT_FOUND}
  WSAHOST_NOT_FOUND       = WSABASEERR + 1001; { authoritative answer: host not found }
  {$EXTERNALSYM WSATRY_AGAIN}
  WSATRY_AGAIN            = WSABASEERR + 1002; { non-authoritative: host not found, or SERVERFAIL }
  {$EXTERNALSYM WSANO_RECOVERY}
  WSANO_RECOVERY          = WSABASEERR + 1003; { non-recoverable errors }
  {$EXTERNALSYM WSANO_DATA}
  WSANO_DATA              = WSABASEERR + 1004; { valid name, no data record of requested type }
  {$EXTERNALSYM WSANO_ADDRESS}
  WSANO_ADDRESS           = WSANO_DATA;
  {$EXTERNALSYM HOST_NOT_FOUND}
  HOST_NOT_FOUND          = WSAHOST_NOT_FOUND;
  {$EXTERNALSYM TRY_AGAIN}
  TRY_AGAIN               = WSATRY_AGAIN;
  {$EXTERNALSYM NO_RECOVERY}
  NO_RECOVERY             = WSANO_RECOVERY;
  {$EXTERNALSYM NO_DATA}
  NO_DATA                 = WSANO_DATA;
  {$EXTERNALSYM NO_ADDRESS}
  NO_ADDRESS              = WSANO_ADDRESS;
  {$EXTERNALSYM WSA_SECURE_HOST_NOT_FOUND}
  WSA_SECURE_HOST_NOT_FOUND   = 11032;
  {$EXTERNALSYM WSA_IPSEC_NAME_POLICY_ERROR}
  WSA_IPSEC_NAME_POLICY_ERROR = 11033;

  { getaddrinfo / getnameinfo errors }
  {$EXTERNALSYM EAI_AGAIN}
  EAI_AGAIN       = WSATRY_AGAIN;
  {$EXTERNALSYM EAI_BADFLAGS}
  EAI_BADFLAGS    = WSAEINVAL;
  {$EXTERNALSYM EAI_FAIL}
  EAI_FAIL        = WSANO_RECOVERY;
  {$EXTERNALSYM EAI_FAMILY}
  EAI_FAMILY      = WSAEAFNOSUPPORT;
  {$EXTERNALSYM EAI_MEMORY}
  EAI_MEMORY      = WSA_NOT_ENOUGH_MEMORY;
  {$EXTERNALSYM EAI_NOSECURENAME}
  EAI_NOSECURENAME = WSA_SECURE_HOST_NOT_FOUND;
  {$EXTERNALSYM EAI_NONAME}
  EAI_NONAME      = WSAHOST_NOT_FOUND;
  {$EXTERNALSYM EAI_SERVICE}
  EAI_SERVICE     = WSATYPE_NOT_FOUND;
  {$EXTERNALSYM EAI_SOCKTYPE}
  EAI_SOCKTYPE    = WSAESOCKTNOSUPPORT;
  {$EXTERNALSYM EAI_IPSECPOLICY}
  EAI_IPSECPOLICY = WSA_IPSEC_NAME_POLICY_ERROR;
  {$EXTERNALSYM EAI_NODATA}
  EAI_NODATA      = EAI_NONAME;

{ ====== I/O control codes (ioctlsocket, WSAIoctl) ========================= }

const
  {$EXTERNALSYM IOCPARM_MASK}
  IOCPARM_MASK = $7F;                     { parameters must be < 128 bytes }
  {$EXTERNALSYM IOC_VOID}
  IOC_VOID     = $20000000;               { no parameters }
  {$EXTERNALSYM IOC_OUT}
  IOC_OUT      = $40000000;               { copy out parameters }
  {$EXTERNALSYM IOC_IN}
  IOC_IN       = $80000000;               { copy in parameters }
  {$EXTERNALSYM IOC_INOUT}
  IOC_INOUT    = IOC_IN or IOC_OUT;
  {$EXTERNALSYM IOC_UNIX}
  IOC_UNIX     = $00000000;
  {$EXTERNALSYM IOC_WS2}
  IOC_WS2      = $08000000;
  {$EXTERNALSYM IOC_PROTOCOL}
  IOC_PROTOCOL = $10000000;
  {$EXTERNALSYM IOC_VENDOR}
  IOC_VENDOR   = $18000000;
  {$EXTERNALSYM IOC_WSK}
  IOC_WSK      = IOC_WS2 or $07000000;

  { ioctlsocket: _IOR / _IOW(x, y, u_long) }
  {$EXTERNALSYM FIONREAD}
  FIONREAD   = IOC_OUT or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('f') shl 8) or 127; { get # bytes to read }
  {$EXTERNALSYM FIONBIO}
  FIONBIO    = IOC_IN or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('f') shl 8) or 126;  { set/clear non-blocking i/o }
  {$EXTERNALSYM FIOASYNC}
  FIOASYNC   = IOC_IN or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('f') shl 8) or 125;  { set/clear async i/o }
  {$EXTERNALSYM SIOCSHIWAT}
  SIOCSHIWAT = IOC_IN or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('s') shl 8) or 0;    { set high watermark }
  {$EXTERNALSYM SIOCGHIWAT}
  SIOCGHIWAT = IOC_OUT or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('s') shl 8) or 1;   { get high watermark }
  {$EXTERNALSYM SIOCSLOWAT}
  SIOCSLOWAT = IOC_IN or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('s') shl 8) or 2;    { set low watermark }
  {$EXTERNALSYM SIOCGLOWAT}
  SIOCGLOWAT = IOC_OUT or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('s') shl 8) or 3;   { get low watermark }
  {$EXTERNALSYM SIOCATMARK}
  SIOCATMARK = IOC_OUT or ((SizeOf(u_long) and IOCPARM_MASK) shl 16) or (Ord('s') shl 8) or 7;   { at oob mark? }

  { WSAIoctl: _WSAIO / _WSAIOR / _WSAIOW / _WSAIORW(IOC_WS2, n) }
  {$EXTERNALSYM SIO_ASSOCIATE_HANDLE}
  SIO_ASSOCIATE_HANDLE                        = IOC_IN or IOC_WS2 or 1;
  {$EXTERNALSYM SIO_ENABLE_CIRCULAR_QUEUEING}
  SIO_ENABLE_CIRCULAR_QUEUEING                = IOC_VOID or IOC_WS2 or 2;
  {$EXTERNALSYM SIO_FIND_ROUTE}
  SIO_FIND_ROUTE                              = IOC_OUT or IOC_WS2 or 3;
  {$EXTERNALSYM SIO_FLUSH}
  SIO_FLUSH                                   = IOC_VOID or IOC_WS2 or 4;
  {$EXTERNALSYM SIO_GET_BROADCAST_ADDRESS}
  SIO_GET_BROADCAST_ADDRESS                   = IOC_OUT or IOC_WS2 or 5;
  {$EXTERNALSYM SIO_GET_EXTENSION_FUNCTION_POINTER}
  SIO_GET_EXTENSION_FUNCTION_POINTER          = IOC_INOUT or IOC_WS2 or 6;
  {$EXTERNALSYM SIO_GET_QOS}
  SIO_GET_QOS                                 = IOC_INOUT or IOC_WS2 or 7;
  {$EXTERNALSYM SIO_GET_GROUP_QOS}
  SIO_GET_GROUP_QOS                           = IOC_INOUT or IOC_WS2 or 8;
  {$EXTERNALSYM SIO_MULTIPOINT_LOOPBACK}
  SIO_MULTIPOINT_LOOPBACK                     = IOC_IN or IOC_WS2 or 9;
  {$EXTERNALSYM SIO_MULTICAST_SCOPE}
  SIO_MULTICAST_SCOPE                         = IOC_IN or IOC_WS2 or 10;
  {$EXTERNALSYM SIO_SET_QOS}
  SIO_SET_QOS                                 = IOC_IN or IOC_WS2 or 11;
  {$EXTERNALSYM SIO_SET_GROUP_QOS}
  SIO_SET_GROUP_QOS                           = IOC_IN or IOC_WS2 or 12;
  {$EXTERNALSYM SIO_TRANSLATE_HANDLE}
  SIO_TRANSLATE_HANDLE                        = IOC_INOUT or IOC_WS2 or 13;
  {$EXTERNALSYM SIO_ROUTING_INTERFACE_QUERY}
  SIO_ROUTING_INTERFACE_QUERY                 = IOC_INOUT or IOC_WS2 or 20;
  {$EXTERNALSYM SIO_ROUTING_INTERFACE_CHANGE}
  SIO_ROUTING_INTERFACE_CHANGE                = IOC_IN or IOC_WS2 or 21;
  {$EXTERNALSYM SIO_ADDRESS_LIST_QUERY}
  SIO_ADDRESS_LIST_QUERY                      = IOC_OUT or IOC_WS2 or 22;
  {$EXTERNALSYM SIO_ADDRESS_LIST_CHANGE}
  SIO_ADDRESS_LIST_CHANGE                     = IOC_VOID or IOC_WS2 or 23;
  {$EXTERNALSYM SIO_QUERY_TARGET_PNP_HANDLE}
  SIO_QUERY_TARGET_PNP_HANDLE                 = IOC_OUT or IOC_WS2 or 24;
  {$EXTERNALSYM SIO_ADDRESS_LIST_SORT}
  SIO_ADDRESS_LIST_SORT                       = IOC_INOUT or IOC_WS2 or 25;
  {$EXTERNALSYM SIO_BSP_HANDLE}
  SIO_BSP_HANDLE                              = IOC_OUT or IOC_WS2 or 27;
  {$EXTERNALSYM SIO_BSP_HANDLE_SELECT}
  SIO_BSP_HANDLE_SELECT                       = IOC_OUT or IOC_WS2 or 28;
  {$EXTERNALSYM SIO_BSP_HANDLE_POLL}
  SIO_BSP_HANDLE_POLL                         = IOC_OUT or IOC_WS2 or 29;
  {$EXTERNALSYM SIO_BASE_HANDLE}
  SIO_BASE_HANDLE                             = IOC_OUT or IOC_WS2 or 34;
  {$EXTERNALSYM SIO_GET_MULTIPLE_EXTENSION_FUNCTION_POINTER}
  SIO_GET_MULTIPLE_EXTENSION_FUNCTION_POINTER = IOC_INOUT or IOC_WS2 or 36;
  {$EXTERNALSYM SIO_QUERY_RSS_PROCESSOR_INFO}
  SIO_QUERY_RSS_PROCESSOR_INFO                = IOC_OUT or IOC_WS2 or 37;

  { WSAIoctl: _WSAIOW(IOC_VENDOR, n) (mstcpip.h, mswsock.h) }
  {$EXTERNALSYM SIO_RCVALL}
  SIO_RCVALL              = IOC_IN or IOC_VENDOR or 1;
  {$EXTERNALSYM SIO_KEEPALIVE_VALS}
  SIO_KEEPALIVE_VALS      = IOC_IN or IOC_VENDOR or 4;   { tcp_keepalive }
  {$EXTERNALSYM SIO_UDP_CONNRESET}
  SIO_UDP_CONNRESET       = IOC_IN or IOC_VENDOR or 12;
  {$EXTERNALSYM SIO_UDP_NETRESET}
  SIO_UDP_NETRESET        = IOC_IN or IOC_VENDOR or 15;
  {$EXTERNALSYM SIO_LOOPBACK_FAST_PATH}
  SIO_LOOPBACK_FAST_PATH  = IOC_IN or IOC_VENDOR or 16;

  { SIO_RCVALL values (RCVALL_VALUE) }
  {$EXTERNALSYM RCVALL_OFF}
  RCVALL_OFF             = 0;
  {$EXTERNALSYM RCVALL_ON}
  RCVALL_ON              = 1;
  {$EXTERNALSYM RCVALL_SOCKETLEVELONLY}
  RCVALL_SOCKETLEVELONLY = 2;
  {$EXTERNALSYM RCVALL_IPLEVEL}
  RCVALL_IPLEVEL         = 3;

  { WSAIoctl: _IOR / _IO('t', n) (ws2ipdef.h) }
  {$EXTERNALSYM SIO_GET_INTERFACE_LIST}
  SIO_GET_INTERFACE_LIST        = IOC_OUT or ((SizeOf(ULONG) and IOCPARM_MASK) shl 16) or (Ord('t') shl 8) or 127;
  {$EXTERNALSYM SIO_GET_INTERFACE_LIST_EX}
  SIO_GET_INTERFACE_LIST_EX     = IOC_OUT or ((SizeOf(ULONG) and IOCPARM_MASK) shl 16) or (Ord('t') shl 8) or 126;
  {$EXTERNALSYM SIO_IDEAL_SEND_BACKLOG_QUERY}
  SIO_IDEAL_SEND_BACKLOG_QUERY  = IOC_OUT or ((SizeOf(ULONG) and IOCPARM_MASK) shl 16) or (Ord('t') shl 8) or 123;
  {$EXTERNALSYM SIO_IDEAL_SEND_BACKLOG_CHANGE}
  SIO_IDEAL_SEND_BACKLOG_CHANGE = IOC_VOID or (Ord('t') shl 8) or 122;

{ ====== Winsock 2 structures ============================================== }

type
  { WSAStartup }
  PWSAData = ^TWSAData;
  {$EXTERNALSYM WSAData}
  WSAData = record
    wVersion: Word;
    wHighVersion: Word;
    szDescription: array[0..WSADESCRIPTION_LEN] of AnsiChar;
    szSystemStatus: array[0..WSASYS_STATUS_LEN] of AnsiChar;
    iMaxSockets: Word;                    { ignored by Winsock 2 }
    iMaxUdpDg: Word;                      { ignored by Winsock 2 }
    lpVendorInfo: PAnsiChar;              { ignored by Winsock 2 }
  end;
  TWSAData = WSAData;
  {$EXTERNALSYM LPWSADATA}
  LPWSADATA = PWSAData;

  { The set of sockets of select (fd_set in C) }
  {$EXTERNALSYM PFD_SET}
  PFD_SET = ^TFDSet;
  TFDSet = record
    fd_count: u_int;                      { how many are set }
    fd_array: array[0..FD_SETSIZE - 1] of TSocket;
  end;
  PFDSet = PFD_SET;
  {$EXTERNALSYM LPFD_SET}
  LPFD_SET = PFD_SET;

  {$EXTERNALSYM PTIMEVAL}
  PTimeVal = ^timeval;
  {$EXTERNALSYM timeval}
  timeval = record
    tv_sec: Longint;                      { seconds }
    tv_usec: Longint;                     { and microseconds }
  end;
  TTimeVal = timeval;
  {$EXTERNALSYM LPTIMEVAL}
  LPTIMEVAL = PTimeVal;

  { SO_LINGER }
  {$EXTERNALSYM PLINGER}
  PLinger = ^linger;
  {$EXTERNALSYM linger}
  linger = record
    l_onoff: u_short;                     { option on/off }
    l_linger: u_short;                    { linger time, seconds }
  end;
  TLinger = linger;
  {$EXTERNALSYM LPLINGER}
  LPLINGER = PLinger;

  { A buffer of WSASend / WSARecv }
  {$EXTERNALSYM LPWSABUF}
  LPWSABUF = ^_WSABUF;
  {$EXTERNALSYM _WSABUF}
  _WSABUF = record
    len: ULONG;                           { the length of the buffer }
    buf: PAnsiChar;                       { the pointer to the buffer }
  end;
  {$EXTERNALSYM WSABUF}
  WSABUF = _WSABUF;
  TWSABuf = _WSABUF;
  PWSABuf = LPWSABUF;

  { Quality of service (qos.h) }
  {$EXTERNALSYM PFLOWSPEC}
  PFlowSpec = ^_flowspec;
  {$EXTERNALSYM _flowspec}
  _flowspec = record
    TokenRate: ULONG;                     { in bytes/sec }
    TokenBucketSize: ULONG;               { in bytes }
    PeakBandwidth: ULONG;                 { in bytes/sec }
    Latency: ULONG;                       { in microseconds }
    DelayVariation: ULONG;                { in microseconds }
    ServiceType: SERVICETYPE;
    MaxSduSize: ULONG;                    { in bytes }
    MinimumPolicedSize: ULONG;            { in bytes }
  end;
  {$EXTERNALSYM FLOWSPEC}
  FLOWSPEC = _flowspec;
  TFlowSpec = _flowspec;
  {$EXTERNALSYM LPFLOWSPEC}
  LPFLOWSPEC = PFlowSpec;

  {$EXTERNALSYM LPQOS}
  LPQOS = ^_QualityOfService;
  {$EXTERNALSYM _QualityOfService}
  _QualityOfService = record
    SendingFlowspec: FLOWSPEC;            { the flow spec for data sending }
    ReceivingFlowspec: FLOWSPEC;          { the flow spec for data receiving }
    ProviderSpecific: WSABUF;             { additional provider specific stuff }
  end;
  {$EXTERNALSYM QOS}
  QOS = _QualityOfService;
  TQOS = _QualityOfService;
  PQOS = LPQOS;

  { WSAEnumNetworkEvents; iErrorCode is indexed by FD_*_BIT }
  {$EXTERNALSYM LPWSANETWORKEVENTS}
  LPWSANETWORKEVENTS = ^_WSANETWORKEVENTS;
  {$EXTERNALSYM _WSANETWORKEVENTS}
  _WSANETWORKEVENTS = record
    lNetworkEvents: Longint;
    iErrorCode: array[0..FD_MAX_EVENTS - 1] of Integer;
  end;
  {$EXTERNALSYM WSANETWORKEVENTS}
  WSANETWORKEVENTS = _WSANETWORKEVENTS;
  TWSANetworkEvents = _WSANETWORKEVENTS;
  PWSANetworkEvents = LPWSANETWORKEVENTS;

  {$EXTERNALSYM LPWSAPROTOCOLCHAIN}
  LPWSAPROTOCOLCHAIN = ^_WSAPROTOCOLCHAIN;
  {$EXTERNALSYM _WSAPROTOCOLCHAIN}
  _WSAPROTOCOLCHAIN = record
    ChainLen: Integer;                    { 0: layered protocol, 1: base protocol, > 1: protocol chain }
    ChainEntries: array[0..6] of DWORD;   { MAX_PROTOCOL_CHAIN dwCatalogEntryIds }
  end;
  {$EXTERNALSYM WSAPROTOCOLCHAIN}
  WSAPROTOCOLCHAIN = _WSAPROTOCOLCHAIN;
  TWSAProtocolChain = _WSAPROTOCOLCHAIN;
  PWSAProtocolChain = LPWSAPROTOCOLCHAIN;

  {$EXTERNALSYM LPWSAPROTOCOL_INFOA}
  LPWSAPROTOCOL_INFOA = ^_WSAPROTOCOL_INFOA;
  {$EXTERNALSYM _WSAPROTOCOL_INFOA}
  _WSAPROTOCOL_INFOA = record
    dwServiceFlags1: DWORD;               { XP1_* }
    dwServiceFlags2: DWORD;
    dwServiceFlags3: DWORD;
    dwServiceFlags4: DWORD;
    dwProviderFlags: DWORD;               { PFL_* }
    ProviderId: TGUID;
    dwCatalogEntryId: DWORD;
    ProtocolChain: WSAPROTOCOLCHAIN;
    iVersion: Integer;
    iAddressFamily: Integer;
    iMaxSockAddr: Integer;
    iMinSockAddr: Integer;
    iSocketType: Integer;
    iProtocol: Integer;
    iProtocolMaxOffset: Integer;
    iNetworkByteOrder: Integer;           { BIGENDIAN, LITTLEENDIAN }
    iSecurityScheme: Integer;
    dwMessageSize: DWORD;
    dwProviderReserved: DWORD;
    szProtocol: array[0..255] of AnsiChar; { WSAPROTOCOL_LEN + 1 }
  end;
  {$EXTERNALSYM WSAPROTOCOL_INFOA}
  WSAPROTOCOL_INFOA = _WSAPROTOCOL_INFOA;
  TWSAProtocolInfoA = _WSAPROTOCOL_INFOA;
  PWSAProtocolInfoA = LPWSAPROTOCOL_INFOA;

  {$EXTERNALSYM LPWSAPROTOCOL_INFOW}
  LPWSAPROTOCOL_INFOW = ^_WSAPROTOCOL_INFOW;
  {$EXTERNALSYM _WSAPROTOCOL_INFOW}
  _WSAPROTOCOL_INFOW = record
    dwServiceFlags1: DWORD;               { XP1_* }
    dwServiceFlags2: DWORD;
    dwServiceFlags3: DWORD;
    dwServiceFlags4: DWORD;
    dwProviderFlags: DWORD;               { PFL_* }
    ProviderId: TGUID;
    dwCatalogEntryId: DWORD;
    ProtocolChain: WSAPROTOCOLCHAIN;
    iVersion: Integer;
    iAddressFamily: Integer;
    iMaxSockAddr: Integer;
    iMinSockAddr: Integer;
    iSocketType: Integer;
    iProtocol: Integer;
    iProtocolMaxOffset: Integer;
    iNetworkByteOrder: Integer;           { BIGENDIAN, LITTLEENDIAN }
    iSecurityScheme: Integer;
    dwMessageSize: DWORD;
    dwProviderReserved: DWORD;
    szProtocol: array[0..255] of WideChar; { WSAPROTOCOL_LEN + 1 }
  end;
  {$EXTERNALSYM WSAPROTOCOL_INFOW}
  WSAPROTOCOL_INFOW = _WSAPROTOCOL_INFOW;
  TWSAProtocolInfoW = _WSAPROTOCOL_INFOW;
  PWSAProtocolInfoW = LPWSAPROTOCOL_INFOW;

  {$EXTERNALSYM WSAPROTOCOL_INFO}
  WSAPROTOCOL_INFO = WSAPROTOCOL_INFOA;
  TWSAProtocolInfo = TWSAProtocolInfoA;
  PWSAProtocolInfo = PWSAProtocolInfoA;
  {$EXTERNALSYM LPWSAPROTOCOL_INFO}
  LPWSAPROTOCOL_INFO = LPWSAPROTOCOL_INFOA;

  { WSAPoll }
  {$EXTERNALSYM PWSAPOLLFD}
  PWSAPollFD = ^pollfd;
  {$EXTERNALSYM pollfd}
  pollfd = record
    fd: TSocket;
    events: Smallint;                     { POLL* requested }
    revents: Smallint;                    { POLL* returned }
  end;
  {$EXTERNALSYM WSAPOLLFD}
  WSAPOLLFD = pollfd;
  TWSAPollFD = pollfd;
  {$EXTERNALSYM LPWSAPOLLFD}
  LPWSAPOLLFD = PWSAPollFD;

  { WSASendMsg, WSARecvMsg }
  {$EXTERNALSYM PWSAMSG}
  PWSAMsg = ^_WSAMSG;
  {$EXTERNALSYM _WSAMSG}
  _WSAMSG = record
    name: PSockAddr;                      { remote address }
    namelen: Integer;                     { remote address length }
    lpBuffers: PWSABuf;                   { data buffer array }
    dwBufferCount: ULONG;                 { number of elements in the array }
    Control: WSABUF;                      { control buffer }
    dwFlags: ULONG;                       { MSG_* }
  end;
  {$EXTERNALSYM WSAMSG}
  WSAMSG = _WSAMSG;
  TWSAMsg = _WSAMSG;
  {$EXTERNALSYM LPWSAMSG}
  LPWSAMSG = PWSAMsg;

  { A control data object in WSAMSG.Control: the header, then the data at
    WSA_CMSG_DATA }
  {$EXTERNALSYM PWSACMSGHDR}
  PWSACMsgHdr = ^WSACMSGHDR;
  {$EXTERNALSYM WSACMSGHDR}
  WSACMSGHDR = record
    cmsg_len: ULONG_PTR;                  { SIZE_T: length of header and data }
    cmsg_level: Integer;
    cmsg_type: Integer;
  end;
  TWSACMsgHdr = WSACMSGHDR;
  {$EXTERNALSYM LPWSACMSGHDR}
  LPWSACMSGHDR = PWSACMsgHdr;

  { SIO_KEEPALIVE_VALS (struct tcp_keepalive of mstcpip.h; the C name is the
    same Pascal identifier as the option TCP_KEEPALIVE) }
  PTCPKeepAlive = ^TTCPKeepAlive;
  TTCPKeepAlive = record
    onoff: ULONG;
    keepalivetime: ULONG;                 { ms }
    keepaliveinterval: ULONG;             { ms }
  end;

  { WSAAccept condition function. Returns CF_ACCEPT, CF_REJECT or CF_DEFER. }
  {$EXTERNALSYM LPCONDITIONPROC}
  LPCONDITIONPROC = function(lpCallerId, lpCallerData: PWSABuf; lpSQOS, lpGQOS: PQOS;
    lpCalleeId, lpCalleeData: PWSABuf; g: PGroup; dwCallbackData: DWORD_PTR): Integer; stdcall;
  TConditionProc = LPCONDITIONPROC;

  { Completion routine of overlapped WSASend, WSARecv, WSAIoctl ... }
  {$EXTERNALSYM LPWSAOVERLAPPED_COMPLETION_ROUTINE}
  LPWSAOVERLAPPED_COMPLETION_ROUTINE = procedure(dwError, cbTransferred: DWORD;
    lpOverlapped: PWSAOverlapped; dwFlags: DWORD); stdcall;
  TWSAOverlappedCompletionRoutine = LPWSAOVERLAPPED_COMPLETION_ROUTINE;

const
  { WSAAccept condition function results }
  {$EXTERNALSYM CF_ACCEPT}
  CF_ACCEPT = $0000;
  {$EXTERNALSYM CF_REJECT}
  CF_REJECT = $0001;
  {$EXTERNALSYM CF_DEFER}
  CF_DEFER  = $0002;

  { Socket groups }
  {$EXTERNALSYM SG_UNCONSTRAINED_GROUP}
  SG_UNCONSTRAINED_GROUP = $01;
  {$EXTERNALSYM SG_CONSTRAINED_GROUP}
  SG_CONSTRAINED_GROUP   = $02;

  { WSAPROTOCOL_INFO }
  {$EXTERNALSYM MAX_PROTOCOL_CHAIN}
  MAX_PROTOCOL_CHAIN = 7;
  {$EXTERNALSYM BASE_PROTOCOL}
  BASE_PROTOCOL      = 1;
  {$EXTERNALSYM LAYERED_PROTOCOL}
  LAYERED_PROTOCOL   = 0;
  {$EXTERNALSYM WSAPROTOCOL_LEN}
  WSAPROTOCOL_LEN    = 255;

  { WSAPROTOCOL_INFO.dwProviderFlags }
  {$EXTERNALSYM PFL_MULTIPLE_PROTO_ENTRIES}
  PFL_MULTIPLE_PROTO_ENTRIES  = $00000001;
  {$EXTERNALSYM PFL_RECOMMENDED_PROTO_ENTRY}
  PFL_RECOMMENDED_PROTO_ENTRY = $00000002;
  {$EXTERNALSYM PFL_HIDDEN}
  PFL_HIDDEN                  = $00000004;
  {$EXTERNALSYM PFL_MATCHES_PROTOCOL_ZERO}
  PFL_MATCHES_PROTOCOL_ZERO   = $00000008;
  {$EXTERNALSYM PFL_NETWORKDIRECT_PROVIDER}
  PFL_NETWORKDIRECT_PROVIDER  = $00000010;

  { WSAPROTOCOL_INFO.dwServiceFlags1 }
  {$EXTERNALSYM XP1_CONNECTIONLESS}
  XP1_CONNECTIONLESS           = $00000001;
  {$EXTERNALSYM XP1_GUARANTEED_DELIVERY}
  XP1_GUARANTEED_DELIVERY      = $00000002;
  {$EXTERNALSYM XP1_GUARANTEED_ORDER}
  XP1_GUARANTEED_ORDER         = $00000004;
  {$EXTERNALSYM XP1_MESSAGE_ORIENTED}
  XP1_MESSAGE_ORIENTED         = $00000008;
  {$EXTERNALSYM XP1_PSEUDO_STREAM}
  XP1_PSEUDO_STREAM            = $00000010;
  {$EXTERNALSYM XP1_GRACEFUL_CLOSE}
  XP1_GRACEFUL_CLOSE           = $00000020;
  {$EXTERNALSYM XP1_EXPEDITED_DATA}
  XP1_EXPEDITED_DATA           = $00000040;
  {$EXTERNALSYM XP1_CONNECT_DATA}
  XP1_CONNECT_DATA             = $00000080;
  {$EXTERNALSYM XP1_DISCONNECT_DATA}
  XP1_DISCONNECT_DATA          = $00000100;
  {$EXTERNALSYM XP1_SUPPORT_BROADCAST}
  XP1_SUPPORT_BROADCAST        = $00000200;
  {$EXTERNALSYM XP1_SUPPORT_MULTIPOINT}
  XP1_SUPPORT_MULTIPOINT       = $00000400;
  {$EXTERNALSYM XP1_MULTIPOINT_CONTROL_PLANE}
  XP1_MULTIPOINT_CONTROL_PLANE = $00000800;
  {$EXTERNALSYM XP1_MULTIPOINT_DATA_PLANE}
  XP1_MULTIPOINT_DATA_PLANE    = $00001000;
  {$EXTERNALSYM XP1_QOS_SUPPORTED}
  XP1_QOS_SUPPORTED            = $00002000;
  {$EXTERNALSYM XP1_INTERRUPT}
  XP1_INTERRUPT                = $00004000;
  {$EXTERNALSYM XP1_UNI_SEND}
  XP1_UNI_SEND                 = $00008000;
  {$EXTERNALSYM XP1_UNI_RECV}
  XP1_UNI_RECV                 = $00010000;
  {$EXTERNALSYM XP1_IFS_HANDLES}
  XP1_IFS_HANDLES              = $00020000;
  {$EXTERNALSYM XP1_PARTIAL_MESSAGE}
  XP1_PARTIAL_MESSAGE          = $00040000;
  {$EXTERNALSYM XP1_SAN_SUPPORT_SDP}
  XP1_SAN_SUPPORT_SDP          = $00080000;

  { WSAPROTOCOL_INFO.iNetworkByteOrder, iSecurityScheme }
  {$EXTERNALSYM BIGENDIAN}
  BIGENDIAN              = $0000;
  {$EXTERNALSYM LITTLEENDIAN}
  LITTLEENDIAN           = $0001;
  {$EXTERNALSYM SECURITY_PROTOCOL_NONE}
  SECURITY_PROTOCOL_NONE = $0000;

  { WSAJoinLeaf }
  {$EXTERNALSYM JL_SENDER_ONLY}
  JL_SENDER_ONLY   = $01;
  {$EXTERNALSYM JL_RECEIVER_ONLY}
  JL_RECEIVER_ONLY = $02;
  {$EXTERNALSYM JL_BOTH}
  JL_BOTH          = $04;

  { WSASocket }
  {$EXTERNALSYM WSA_FLAG_OVERLAPPED}
  WSA_FLAG_OVERLAPPED             = $01;
  {$EXTERNALSYM WSA_FLAG_MULTIPOINT_C_ROOT}
  WSA_FLAG_MULTIPOINT_C_ROOT      = $02;
  {$EXTERNALSYM WSA_FLAG_MULTIPOINT_C_LEAF}
  WSA_FLAG_MULTIPOINT_C_LEAF      = $04;
  {$EXTERNALSYM WSA_FLAG_MULTIPOINT_D_ROOT}
  WSA_FLAG_MULTIPOINT_D_ROOT      = $08;
  {$EXTERNALSYM WSA_FLAG_MULTIPOINT_D_LEAF}
  WSA_FLAG_MULTIPOINT_D_LEAF      = $10;
  {$EXTERNALSYM WSA_FLAG_ACCESS_SYSTEM_SECURITY}
  WSA_FLAG_ACCESS_SYSTEM_SECURITY = $40;
  {$EXTERNALSYM WSA_FLAG_NO_HANDLE_INHERIT}
  WSA_FLAG_NO_HANDLE_INHERIT      = $80;  { Windows 7 SP1 and later }
  {$EXTERNALSYM WSA_FLAG_REGISTERED_IO}
  WSA_FLAG_REGISTERED_IO          = $100; { Windows 8 and later }

{ ====== Name resolution (winsock2.h, ws2def.h, ws2tcpip.h) ================ }

type
  {$EXTERNALSYM PHOSTENT}
  PHostEnt = ^hostent;
  {$EXTERNALSYM hostent}
  hostent = record
    h_name: PAnsiChar;                    { official name of host }
    h_aliases: PPAnsiChar;                { alias list }
    h_addrtype: Smallint;                 { host address type }
    h_length: Smallint;                   { length of address }
    h_addr_list: PPAnsiChar;              { list of addresses (h_addr is h_addr_list^) }
  end;
  THostEnt = hostent;
  {$EXTERNALSYM LPHOSTENT}
  LPHOSTENT = PHostEnt;

  {$EXTERNALSYM PSERVENT}
  PServEnt = ^servent;
  {$EXTERNALSYM servent}
  servent = record
    s_name: PAnsiChar;                    { official service name }
    s_aliases: PPAnsiChar;                { alias list }
    s_port: Smallint;                     { port #, network byte order }
    s_proto: PAnsiChar;                   { protocol to use }
  end;
  TServEnt = servent;
  {$EXTERNALSYM LPSERVENT}
  LPSERVENT = PServEnt;

  {$EXTERNALSYM PPROTOENT}
  PProtoEnt = ^protoent;
  {$EXTERNALSYM protoent}
  protoent = record
    p_name: PAnsiChar;                    { official protocol name }
    p_aliases: PPAnsiChar;                { alias list }
    p_proto: Smallint;                    { protocol # }
  end;
  TProtoEnt = protoent;
  {$EXTERNALSYM LPPROTOENT}
  LPPROTOENT = PProtoEnt;

  { getaddrinfo (ADDRINFOA, ADDRINFO) }
  {$EXTERNALSYM PADDRINFOA}
  PAddrInfoA = ^addrinfo;
  {$EXTERNALSYM addrinfo}
  addrinfo = record
    ai_flags: Integer;                    { AI_* }
    ai_family: Integer;                   { PF_* }
    ai_socktype: Integer;                 { SOCK_* }
    ai_protocol: Integer;                 { 0 or IPPROTO_* }
    ai_addrlen: ULONG_PTR;                { length of ai_addr }
    ai_canonname: PAnsiChar;              { canonical name for nodename }
    ai_addr: PSockAddr;                   { binary address }
    ai_next: PAddrInfoA;                  { next structure in linked list }
  end;
  {$EXTERNALSYM ADDRINFOA}
  ADDRINFOA = addrinfo;
  TAddrInfoA = addrinfo;
  TAddrInfo = addrinfo;
  PAddrInfo = PAddrInfoA;
  {$EXTERNALSYM LPADDRINFO}
  LPADDRINFO = PAddrInfoA;

  { GetAddrInfoW }
  {$EXTERNALSYM PADDRINFOW}
  PAddrInfoW = ^addrinfoW;
  {$EXTERNALSYM addrinfoW}
  addrinfoW = record
    ai_flags: Integer;                    { AI_* }
    ai_family: Integer;                   { PF_* }
    ai_socktype: Integer;                 { SOCK_* }
    ai_protocol: Integer;                 { 0 or IPPROTO_* }
    ai_addrlen: ULONG_PTR;                { length of ai_addr }
    ai_canonname: PWideChar;              { canonical name for nodename }
    ai_addr: PSockAddr;                   { binary address }
    ai_next: PAddrInfoW;                  { next structure in linked list }
  end;
  TAddrInfoW = addrinfoW;

  { GetAddrInfoExW }
  {$EXTERNALSYM PADDRINFOEXW}
  PAddrInfoExW = ^addrinfoexW;
  {$EXTERNALSYM addrinfoexW}
  addrinfoexW = record
    ai_flags: Integer;                    { AI_* }
    ai_family: Integer;                   { PF_* }
    ai_socktype: Integer;                 { SOCK_* }
    ai_protocol: Integer;                 { 0 or IPPROTO_* }
    ai_addrlen: ULONG_PTR;                { length of ai_addr }
    ai_canonname: PWideChar;              { canonical name for nodename }
    ai_addr: PSockAddr;                   { binary address }
    ai_blob: Pointer;
    ai_bloblen: ULONG_PTR;
    ai_provider: PGUID;
    ai_next: PAddrInfoExW;                { next structure in linked list }
  end;
  TAddrInfoExW = addrinfoexW;
  {$EXTERNALSYM LPADDRINFOEXW}
  LPADDRINFOEXW = PAddrInfoExW;

  { Completion routine of an asynchronous GetAddrInfoExW }
  {$EXTERNALSYM LPLOOKUPSERVICE_COMPLETION_ROUTINE}
  LPLOOKUPSERVICE_COMPLETION_ROUTINE = procedure(dwError, dwBytes: DWORD;
    lpOverlapped: PWSAOverlapped); stdcall;
  TLookupServiceCompletionRoutine = LPLOOKUPSERVICE_COMPLETION_ROUTINE;

const
  { addrinfo.ai_flags (getaddrinfo hints) }
  {$EXTERNALSYM AI_PASSIVE}
  AI_PASSIVE                = $00000001;  { socket address will be used in bind() }
  {$EXTERNALSYM AI_CANONNAME}
  AI_CANONNAME              = $00000002;  { return canonical name in first ai_canonname }
  {$EXTERNALSYM AI_NUMERICHOST}
  AI_NUMERICHOST            = $00000004;  { nodename must be a numeric address string }
  {$EXTERNALSYM AI_NUMERICSERV}
  AI_NUMERICSERV            = $00000008;  { servicename must be a numeric port number }
  {$EXTERNALSYM AI_DNS_ONLY}
  AI_DNS_ONLY               = $00000010;  { restrict queries to unicast DNS only }
  {$EXTERNALSYM AI_ALL}
  AI_ALL                    = $00000100;  { query both IP6 and IP4 with AI_V4MAPPED }
  {$EXTERNALSYM AI_ADDRCONFIG}
  AI_ADDRCONFIG             = $00000400;  { resolution only if global address configured }
  {$EXTERNALSYM AI_V4MAPPED}
  AI_V4MAPPED               = $00000800;  { on v6 failure, query v4 and convert to V4MAPPED format }
  {$EXTERNALSYM AI_NON_AUTHORITATIVE}
  AI_NON_AUTHORITATIVE      = $00004000;
  {$EXTERNALSYM AI_SECURE}
  AI_SECURE                 = $00008000;
  {$EXTERNALSYM AI_RETURN_PREFERRED_NAMES}
  AI_RETURN_PREFERRED_NAMES = $00010000;
  {$EXTERNALSYM AI_FQDN}
  AI_FQDN                   = $00020000;  { return the FQDN in ai_canonname }
  {$EXTERNALSYM AI_FILESERVER}
  AI_FILESERVER             = $00040000;  { resolving fileserver name resolution }
  {$EXTERNALSYM AI_DISABLE_IDN_ENCODING}
  AI_DISABLE_IDN_ENCODING   = $00080000;  { disable internationalized domain names handling }

  { getnameinfo flags and buffer sizes }
  {$EXTERNALSYM NI_NOFQDN}
  NI_NOFQDN      = $01;                   { only return nodename portion for local hosts }
  {$EXTERNALSYM NI_NUMERICHOST}
  NI_NUMERICHOST = $02;                   { return numeric form of the host's address }
  {$EXTERNALSYM NI_NAMEREQD}
  NI_NAMEREQD    = $04;                   { error if the host's name not in DNS }
  {$EXTERNALSYM NI_NUMERICSERV}
  NI_NUMERICSERV = $08;                   { return numeric form of the service (port #) }
  {$EXTERNALSYM NI_DGRAM}
  NI_DGRAM       = $10;                   { service is a datagram service }
  {$EXTERNALSYM NI_MAXHOST}
  NI_MAXHOST     = 1025;                  { max size of a fully-qualified domain name }
  {$EXTERNALSYM NI_MAXSERV}
  NI_MAXSERV     = 32;                    { max size of a service name }

  { Name spaces (GetAddrInfoExW dwNameSpace) }
  {$EXTERNALSYM NS_ALL}
  NS_ALL         = 0;
  {$EXTERNALSYM NS_SAP}
  NS_SAP         = 1;
  {$EXTERNALSYM NS_NDS}
  NS_NDS         = 2;
  {$EXTERNALSYM NS_PEER_BROWSE}
  NS_PEER_BROWSE = 3;
  {$EXTERNALSYM NS_SLP}
  NS_SLP         = 5;
  {$EXTERNALSYM NS_DHCP}
  NS_DHCP        = 6;
  {$EXTERNALSYM NS_TCPIP_LOCAL}
  NS_TCPIP_LOCAL = 10;
  {$EXTERNALSYM NS_TCPIP_HOSTS}
  NS_TCPIP_HOSTS = 11;
  {$EXTERNALSYM NS_DNS}
  NS_DNS         = 12;
  {$EXTERNALSYM NS_NETBT}
  NS_NETBT       = 13;
  {$EXTERNALSYM NS_WINS}
  NS_WINS        = 14;
  {$EXTERNALSYM NS_NLA}
  NS_NLA         = 15;                    { network location awareness }
  {$EXTERNALSYM NS_BTH}
  NS_BTH         = 16;                    { Bluetooth SDP name space }
  {$EXTERNALSYM NS_NBP}
  NS_NBP         = 20;
  {$EXTERNALSYM NS_MS}
  NS_MS          = 30;
  {$EXTERNALSYM NS_STDA}
  NS_STDA        = 31;
  {$EXTERNALSYM NS_NTDS}
  NS_NTDS        = 32;
  {$EXTERNALSYM NS_EMAIL}
  NS_EMAIL       = 37;
  {$EXTERNALSYM NS_PNRPNAME}
  NS_PNRPNAME    = 38;
  {$EXTERNALSYM NS_PNRPCLOUD}
  NS_PNRPCLOUD   = 39;
  {$EXTERNALSYM NS_X500}
  NS_X500        = 40;
  {$EXTERNALSYM NS_NIS}
  NS_NIS         = 41;
  {$EXTERNALSYM NS_NISPLUS}
  NS_NISPLUS     = 42;
  {$EXTERNALSYM NS_WRQ}
  NS_WRQ         = 50;
  {$EXTERNALSYM NS_NETDES}
  NS_NETDES      = 60;                    { Network Designers Limited }

{ ====== Extension functions (mswsock.h) ===================================
  Obtained with WSAIoctl(s, SIO_GET_EXTENSION_FUNCTION_POINTER, @WSAID_x,
  SizeOf(TGUID), @Fn, SizeOf(Fn), Bytes, nil, nil); the pointer belongs to
  the provider of that socket. }

type
  PTransmitFileBuffers = ^_TRANSMIT_FILE_BUFFERS;
  {$EXTERNALSYM _TRANSMIT_FILE_BUFFERS}
  _TRANSMIT_FILE_BUFFERS = record
    Head: Pointer;
    HeadLength: DWORD;
    Tail: Pointer;
    TailLength: DWORD;
  end;
  {$EXTERNALSYM TRANSMIT_FILE_BUFFERS}
  TRANSMIT_FILE_BUFFERS = _TRANSMIT_FILE_BUFFERS;
  TTransmitFileBuffers = _TRANSMIT_FILE_BUFFERS;
  {$EXTERNALSYM PTRANSMIT_FILE_BUFFERS}
  PTRANSMIT_FILE_BUFFERS = PTransmitFileBuffers;
  {$EXTERNALSYM LPTRANSMIT_FILE_BUFFERS}
  LPTRANSMIT_FILE_BUFFERS = PTransmitFileBuffers;

  {$EXTERNALSYM LPFN_TRANSMITFILE}
  LPFN_TRANSMITFILE = function(hSocket: TSocket; hFile: THandle;
    nNumberOfBytesToWrite, nNumberOfBytesPerSend: DWORD; lpOverlapped: POverlapped;
    lpTransmitBuffers: PTransmitFileBuffers; dwReserved: DWORD): BOOL; stdcall;
  {$EXTERNALSYM LPFN_ACCEPTEX}
  LPFN_ACCEPTEX = function(sListenSocket, sAcceptSocket: TSocket; lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    lpdwBytesReceived: PDWORD; lpOverlapped: POverlapped): BOOL; stdcall;
  {$EXTERNALSYM LPFN_GETACCEPTEXSOCKADDRS}
  LPFN_GETACCEPTEXSOCKADDRS = procedure(lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    var LocalSockaddr: PSockAddr; var LocalSockaddrLength: Integer;
    var RemoteSockaddr: PSockAddr; var RemoteSockaddrLength: Integer); stdcall;
  {$EXTERNALSYM LPFN_CONNECTEX}
  LPFN_CONNECTEX = function(s: TSocket; name: PSockAddr; namelen: Integer;
    lpSendBuffer: Pointer; dwSendDataLength: DWORD; lpdwBytesSent: PDWORD;
    lpOverlapped: POverlapped): BOOL; stdcall;
  {$EXTERNALSYM LPFN_DISCONNECTEX}
  LPFN_DISCONNECTEX = function(s: TSocket; lpOverlapped: POverlapped;
    dwFlags, dwReserved: DWORD): BOOL; stdcall;
  {$EXTERNALSYM LPFN_WSARECVMSG}
  LPFN_WSARECVMSG = function(s: TSocket; lpMsg: PWSAMsg; lpdwNumberOfBytesRecvd: PDWORD;
    lpOverlapped: PWSAOverlapped;
    lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;

const
  {$EXTERNALSYM WSAID_TRANSMITFILE}
  WSAID_TRANSMITFILE: TGUID = '{B5367DF0-CBAC-11CF-95CA-00805F48A192}';
  {$EXTERNALSYM WSAID_ACCEPTEX}
  WSAID_ACCEPTEX: TGUID = '{B5367DF1-CBAC-11CF-95CA-00805F48A192}';
  {$EXTERNALSYM WSAID_GETACCEPTEXSOCKADDRS}
  WSAID_GETACCEPTEXSOCKADDRS: TGUID = '{B5367DF2-CBAC-11CF-95CA-00805F48A192}';
  {$EXTERNALSYM WSAID_CONNECTEX}
  WSAID_CONNECTEX: TGUID = '{25A207B9-DDF3-4660-8EE9-76E58C74063E}';
  {$EXTERNALSYM WSAID_DISCONNECTEX}
  WSAID_DISCONNECTEX: TGUID = '{7FDA2E11-8630-436F-A031-F536A6EEC157}';
  {$EXTERNALSYM WSAID_WSARECVMSG}
  WSAID_WSARECVMSG: TGUID = '{F689D7C8-6F1F-436B-8A53-E54FE351C322}';

  { TransmitFile / DisconnectEx flags }
  {$EXTERNALSYM TF_DISCONNECT}
  TF_DISCONNECT         = $01;
  {$EXTERNALSYM TF_REUSE_SOCKET}
  TF_REUSE_SOCKET       = $02;
  {$EXTERNALSYM TF_WRITE_BEHIND}
  TF_WRITE_BEHIND       = $04;
  {$EXTERNALSYM TF_USE_DEFAULT_WORKER}
  TF_USE_DEFAULT_WORKER = $00;
  {$EXTERNALSYM TF_USE_SYSTEM_THREAD}
  TF_USE_SYSTEM_THREAD  = $10;
  {$EXTERNALSYM TF_USE_KERNEL_APC}
  TF_USE_KERNEL_APC     = $20;
  {$EXTERNALSYM DE_REUSE_SOCKET}
  DE_REUSE_SOCKET       = TF_REUSE_SOCKET;

{ ====== Functions: BSD sockets ============================================ }

{$EXTERNALSYM accept}
function accept(s: TSocket; addr: PSockAddr; addrlen: PInteger): TSocket; stdcall;
{$EXTERNALSYM bind}
function bind(s: TSocket; name: PSockAddr; namelen: Integer): Integer; stdcall;
{$EXTERNALSYM closesocket}
function closesocket(s: TSocket): Integer; stdcall;
{$EXTERNALSYM connect}
function connect(s: TSocket; name: PSockAddr; namelen: Integer): Integer; stdcall;
{ cmd is a long in C; DWORD here, so that the FIO* and SIO* constants (above
  $7FFFFFFF) can be passed. }
{$EXTERNALSYM ioctlsocket}
function ioctlsocket(s: TSocket; cmd: DWORD; var argp: u_long): Integer; stdcall;
{$EXTERNALSYM getpeername}
function getpeername(s: TSocket; name: PSockAddr; var namelen: Integer): Integer; stdcall;
{$EXTERNALSYM getsockname}
function getsockname(s: TSocket; name: PSockAddr; var namelen: Integer): Integer; stdcall;
{$EXTERNALSYM getsockopt}
function getsockopt(s: TSocket; level, optname: Integer; optval: PAnsiChar;
  var optlen: Integer): Integer; stdcall;
{$EXTERNALSYM htonl}
function htonl(hostlong: u_long): u_long; stdcall;
{$EXTERNALSYM htons}
function htons(hostshort: u_short): u_short; stdcall;
{ Returns INADDR_NONE for an invalid string. }
{$EXTERNALSYM inet_addr}
function inet_addr(cp: PAnsiChar): u_long; stdcall;
{ The result is a per-thread buffer, valid until the next Winsock call of the
  thread. }
{$EXTERNALSYM inet_ntoa}
function inet_ntoa(inaddr: in_addr): PAnsiChar; stdcall;
{$EXTERNALSYM listen}
function listen(s: TSocket; backlog: Integer): Integer; stdcall;
{$EXTERNALSYM ntohl}
function ntohl(netlong: u_long): u_long; stdcall;
{$EXTERNALSYM ntohs}
function ntohs(netshort: u_short): u_short; stdcall;
{$EXTERNALSYM recv}
function recv(s: TSocket; var buf; len, flags: Integer): Integer; stdcall;
{$EXTERNALSYM recvfrom}
function recvfrom(s: TSocket; var buf; len, flags: Integer; from: PSockAddr;
  fromlen: PInteger): Integer; stdcall;
{ nfds is ignored (Berkeley compatibility). }
{$EXTERNALSYM select}
function select(nfds: Integer; readfds, writefds, exceptfds: PFDSet;
  timeout: PTimeVal): Integer; stdcall;
{$EXTERNALSYM send}
function send(s: TSocket; const buf; len, flags: Integer): Integer; stdcall;
{$EXTERNALSYM sendto}
function sendto(s: TSocket; const buf; len, flags: Integer; addrto: PSockAddr;
  tolen: Integer): Integer; stdcall;
{$EXTERNALSYM setsockopt}
function setsockopt(s: TSocket; level, optname: Integer; optval: PAnsiChar;
  optlen: Integer): Integer; stdcall;
{$EXTERNALSYM shutdown}
function shutdown(s: TSocket; how: Integer): Integer; stdcall;
{$EXTERNALSYM socket}
function socket(af, type_, protocol: Integer): TSocket; stdcall;

{ Database functions. The results are per-thread buffers, valid until the
  next database call of the thread. }
{$EXTERNALSYM gethostbyaddr}
function gethostbyaddr(addr: PAnsiChar; len, type_: Integer): PHostEnt; stdcall;
{$EXTERNALSYM gethostbyname}
function gethostbyname(name: PAnsiChar): PHostEnt; stdcall;
{$EXTERNALSYM gethostname}
function gethostname(name: PAnsiChar; namelen: Integer): Integer; stdcall;
{$EXTERNALSYM getservbyport}
function getservbyport(port: Integer; proto: PAnsiChar): PServEnt; stdcall;
{$EXTERNALSYM getservbyname}
function getservbyname(name, proto: PAnsiChar): PServEnt; stdcall;
{$EXTERNALSYM getprotobynumber}
function getprotobynumber(number: Integer): PProtoEnt; stdcall;
{$EXTERNALSYM getprotobyname}
function getprotobyname(name: PAnsiChar): PProtoEnt; stdcall;

{ ====== Functions: Windows Sockets extensions ============================= }

{$EXTERNALSYM WSAStartup}
function WSAStartup(wVersionRequested: Word; var lpWSAData: TWSAData): Integer; stdcall;
{$EXTERNALSYM WSACleanup}
function WSACleanup: Integer; stdcall;
{$EXTERNALSYM WSASetLastError}
procedure WSASetLastError(iError: Integer); stdcall;
{$EXTERNALSYM WSAGetLastError}
function WSAGetLastError: Integer; stdcall;

{ Winsock 1.1 blocking hooks: Winsock 2 does not implement them (they fail
  with WSAEOPNOTSUPP). }
{$EXTERNALSYM WSAIsBlocking}
function WSAIsBlocking: BOOL; stdcall;
{$EXTERNALSYM WSAUnhookBlockingHook}
function WSAUnhookBlockingHook: Integer; stdcall;
{$EXTERNALSYM WSASetBlockingHook}
function WSASetBlockingHook(lpBlockFunc: TFarProc): TFarProc; stdcall;
{$EXTERNALSYM WSACancelBlockingCall}
function WSACancelBlockingCall: Integer; stdcall;

{ Asynchronous database functions: the result is posted to hWnd as wMsg
  (WSAGETASYNCBUFLEN, WSAGETASYNCERROR); buf receives the structure. }
{$EXTERNALSYM WSAAsyncGetServByName}
function WSAAsyncGetServByName(hWnd: HWND; wMsg: u_int; name, proto: PAnsiChar;
  buf: PAnsiChar; buflen: Integer): THandle; stdcall;
{$EXTERNALSYM WSAAsyncGetServByPort}
function WSAAsyncGetServByPort(hWnd: HWND; wMsg: u_int; port: Integer; proto: PAnsiChar;
  buf: PAnsiChar; buflen: Integer): THandle; stdcall;
{$EXTERNALSYM WSAAsyncGetProtoByName}
function WSAAsyncGetProtoByName(hWnd: HWND; wMsg: u_int; name: PAnsiChar;
  buf: PAnsiChar; buflen: Integer): THandle; stdcall;
{$EXTERNALSYM WSAAsyncGetProtoByNumber}
function WSAAsyncGetProtoByNumber(hWnd: HWND; wMsg: u_int; number: Integer;
  buf: PAnsiChar; buflen: Integer): THandle; stdcall;
{$EXTERNALSYM WSAAsyncGetHostByName}
function WSAAsyncGetHostByName(hWnd: HWND; wMsg: u_int; name: PAnsiChar;
  buf: PAnsiChar; buflen: Integer): THandle; stdcall;
{$EXTERNALSYM WSAAsyncGetHostByAddr}
function WSAAsyncGetHostByAddr(hWnd: HWND; wMsg: u_int; addr: PAnsiChar; len, type_: Integer;
  buf: PAnsiChar; buflen: Integer): THandle; stdcall;
{$EXTERNALSYM WSACancelAsyncRequest}
function WSACancelAsyncRequest(hAsyncTaskHandle: THandle): Integer; stdcall;
{ Posts wMsg to hWnd for the FD_* events in lEvent (WSAGETSELECTEVENT,
  WSAGETSELECTERROR); makes the socket non-blocking. }
{$EXTERNALSYM WSAAsyncSelect}
function WSAAsyncSelect(s: TSocket; hWnd: HWND; wMsg: u_int; lEvent: Longint): Integer; stdcall;

{$EXTERNALSYM WSAAccept}
function WSAAccept(s: TSocket; addr: PSockAddr; addrlen: PInteger;
  lpfnCondition: LPCONDITIONPROC; dwCallbackData: DWORD_PTR): TSocket; stdcall;
{$EXTERNALSYM WSACloseEvent}
function WSACloseEvent(hEvent: WSAEVENT): BOOL; stdcall;
{$EXTERNALSYM WSAConnect}
function WSAConnect(s: TSocket; name: PSockAddr; namelen: Integer;
  lpCallerData, lpCalleeData: PWSABuf; lpSQOS, lpGQOS: PQOS): Integer; stdcall;
{$EXTERNALSYM WSACreateEvent}
function WSACreateEvent: WSAEVENT; stdcall;
{$EXTERNALSYM WSADuplicateSocketA}
function WSADuplicateSocketA(s: TSocket; dwProcessId: DWORD;
  var lpProtocolInfo: TWSAProtocolInfoA): Integer; stdcall;
{$EXTERNALSYM WSADuplicateSocketW}
function WSADuplicateSocketW(s: TSocket; dwProcessId: DWORD;
  var lpProtocolInfo: TWSAProtocolInfoW): Integer; stdcall;
{$EXTERNALSYM WSADuplicateSocket}
function WSADuplicateSocket(s: TSocket; dwProcessId: DWORD;
  var lpProtocolInfo: TWSAProtocolInfoA): Integer; stdcall;
{$EXTERNALSYM WSAEnumNetworkEvents}
function WSAEnumNetworkEvents(s: TSocket; hEventObject: WSAEVENT;
  var lpNetworkEvents: TWSANetworkEvents): Integer; stdcall;
{ Called with lpProtocolBuffer = nil, fails with WSAENOBUFS and returns the
  size needed in lpdwBufferLength; returns the number of structures. }
{$EXTERNALSYM WSAEnumProtocolsA}
function WSAEnumProtocolsA(lpiProtocols: PInteger; lpProtocolBuffer: PWSAProtocolInfoA;
  var lpdwBufferLength: DWORD): Integer; stdcall;
{$EXTERNALSYM WSAEnumProtocolsW}
function WSAEnumProtocolsW(lpiProtocols: PInteger; lpProtocolBuffer: PWSAProtocolInfoW;
  var lpdwBufferLength: DWORD): Integer; stdcall;
{$EXTERNALSYM WSAEnumProtocols}
function WSAEnumProtocols(lpiProtocols: PInteger; lpProtocolBuffer: PWSAProtocolInfoA;
  var lpdwBufferLength: DWORD): Integer; stdcall;
{ Signals hEventObject for the FD_* events in lNetworkEvents; makes the
  socket non-blocking. }
{$EXTERNALSYM WSAEventSelect}
function WSAEventSelect(s: TSocket; hEventObject: WSAEVENT; lNetworkEvents: Longint): Integer; stdcall;
{$EXTERNALSYM WSAGetOverlappedResult}
function WSAGetOverlappedResult(s: TSocket; lpOverlapped: PWSAOverlapped;
  var lpcbTransfer: DWORD; fWait: BOOL; var lpdwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM WSAHtonl}
function WSAHtonl(s: TSocket; hostlong: u_long; var lpnetlong: u_long): Integer; stdcall;
{$EXTERNALSYM WSAHtons}
function WSAHtons(s: TSocket; hostshort: u_short; var lpnetshort: u_short): Integer; stdcall;
{$EXTERNALSYM WSAIoctl}
function WSAIoctl(s: TSocket; dwIoControlCode: DWORD; lpvInBuffer: Pointer; cbInBuffer: DWORD;
  lpvOutBuffer: Pointer; cbOutBuffer: DWORD; var lpcbBytesReturned: DWORD;
  lpOverlapped: PWSAOverlapped; lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
{$EXTERNALSYM WSAJoinLeaf}
function WSAJoinLeaf(s: TSocket; name: PSockAddr; namelen: Integer;
  lpCallerData, lpCalleeData: PWSABuf; lpSQOS, lpGQOS: PQOS; dwFlags: DWORD): TSocket; stdcall;
{$EXTERNALSYM WSANtohl}
function WSANtohl(s: TSocket; netlong: u_long; var lphostlong: u_long): Integer; stdcall;
{$EXTERNALSYM WSANtohs}
function WSANtohs(s: TSocket; netshort: u_short; var lphostshort: u_short): Integer; stdcall;
{$EXTERNALSYM WSARecv}
function WSARecv(s: TSocket; lpBuffers: PWSABuf; dwBufferCount: DWORD;
  lpNumberOfBytesRecvd: PDWORD; var lpFlags: DWORD; lpOverlapped: PWSAOverlapped;
  lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
{$EXTERNALSYM WSARecvDisconnect}
function WSARecvDisconnect(s: TSocket; lpInboundDisconnectData: PWSABuf): Integer; stdcall;
{$EXTERNALSYM WSARecvFrom}
function WSARecvFrom(s: TSocket; lpBuffers: PWSABuf; dwBufferCount: DWORD;
  lpNumberOfBytesRecvd: PDWORD; var lpFlags: DWORD; lpFrom: PSockAddr; lpFromlen: PInteger;
  lpOverlapped: PWSAOverlapped; lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
{$EXTERNALSYM WSAResetEvent}
function WSAResetEvent(hEvent: WSAEVENT): BOOL; stdcall;
{$EXTERNALSYM WSASend}
function WSASend(s: TSocket; lpBuffers: PWSABuf; dwBufferCount: DWORD;
  lpNumberOfBytesSent: PDWORD; dwFlags: DWORD; lpOverlapped: PWSAOverlapped;
  lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
{$EXTERNALSYM WSASendDisconnect}
function WSASendDisconnect(s: TSocket; lpOutboundDisconnectData: PWSABuf): Integer; stdcall;
{$EXTERNALSYM WSASendTo}
function WSASendTo(s: TSocket; lpBuffers: PWSABuf; dwBufferCount: DWORD;
  lpNumberOfBytesSent: PDWORD; dwFlags: DWORD; lpTo: PSockAddr; iTolen: Integer;
  lpOverlapped: PWSAOverlapped; lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
{$EXTERNALSYM WSASetEvent}
function WSASetEvent(hEvent: WSAEVENT): BOOL; stdcall;
{$EXTERNALSYM WSASocketA}
function WSASocketA(af, type_, protocol: Integer; lpProtocolInfo: PWSAProtocolInfoA;
  g: GROUP; dwFlags: DWORD): TSocket; stdcall;
{$EXTERNALSYM WSASocketW}
function WSASocketW(af, type_, protocol: Integer; lpProtocolInfo: PWSAProtocolInfoW;
  g: GROUP; dwFlags: DWORD): TSocket; stdcall;
{$EXTERNALSYM WSASocket}
function WSASocket(af, type_, protocol: Integer; lpProtocolInfo: PWSAProtocolInfoA;
  g: GROUP; dwFlags: DWORD): TSocket; stdcall;
{ lphEvents points to cEvents events (at most WSA_MAXIMUM_WAIT_EVENTS);
  returns WSA_WAIT_EVENT_0 + index, WSA_WAIT_IO_COMPLETION, WSA_WAIT_TIMEOUT
  or WSA_WAIT_FAILED. }
{$EXTERNALSYM WSAWaitForMultipleEvents}
function WSAWaitForMultipleEvents(cEvents: DWORD; lphEvents: PWSAEvent; fWaitAll: BOOL;
  dwTimeout: DWORD; fAlertable: BOOL): DWORD; stdcall;
{ Address <-> string ("1.2.3.4:80", "[::1]:80"); lengths in characters,
  including the terminating null. }
{$EXTERNALSYM WSAAddressToStringA}
function WSAAddressToStringA(lpsaAddress: PSockAddr; dwAddressLength: DWORD;
  lpProtocolInfo: PWSAProtocolInfoA; lpszAddressString: PAnsiChar;
  var lpdwAddressStringLength: DWORD): Integer; stdcall;
{$EXTERNALSYM WSAAddressToStringW}
function WSAAddressToStringW(lpsaAddress: PSockAddr; dwAddressLength: DWORD;
  lpProtocolInfo: PWSAProtocolInfoW; lpszAddressString: PWideChar;
  var lpdwAddressStringLength: DWORD): Integer; stdcall;
{$EXTERNALSYM WSAAddressToString}
function WSAAddressToString(lpsaAddress: PSockAddr; dwAddressLength: DWORD;
  lpProtocolInfo: PWSAProtocolInfoA; lpszAddressString: PAnsiChar;
  var lpdwAddressStringLength: DWORD): Integer; stdcall;
{$EXTERNALSYM WSAStringToAddressA}
function WSAStringToAddressA(AddressString: PAnsiChar; AddressFamily: Integer;
  lpProtocolInfo: PWSAProtocolInfoA; lpAddress: PSockAddr;
  var lpAddressLength: Integer): Integer; stdcall;
{$EXTERNALSYM WSAStringToAddressW}
function WSAStringToAddressW(AddressString: PWideChar; AddressFamily: Integer;
  lpProtocolInfo: PWSAProtocolInfoW; lpAddress: PSockAddr;
  var lpAddressLength: Integer): Integer; stdcall;
{$EXTERNALSYM WSAStringToAddress}
function WSAStringToAddress(AddressString: PAnsiChar; AddressFamily: Integer;
  lpProtocolInfo: PWSAProtocolInfoA; lpAddress: PSockAddr;
  var lpAddressLength: Integer): Integer; stdcall;

{ select's set test (FD_ISSET calls it) }
{$EXTERNALSYM __WSAFDIsSet}
function __WSAFDIsSet(fd: TSocket; var FDSet: TFDSet): Integer; stdcall;

{ ====== Functions: protocol-independent name resolution (ws2tcpip.h) ====== }

{ Returns 0 or an EAI_* error; the list is freed with freeaddrinfo.
  GetAddrInfo and GetAddrInfoA are the same function. }
{$EXTERNALSYM getaddrinfo}
function getaddrinfo(pNodeName, pServiceName: PAnsiChar; pHints: PAddrInfoA;
  var ppResult: PAddrInfoA): Integer; stdcall;
{$EXTERNALSYM GetAddrInfoA}
function GetAddrInfoA(pNodeName, pServiceName: PAnsiChar; pHints: PAddrInfoA;
  var ppResult: PAddrInfoA): Integer; stdcall;
{$EXTERNALSYM freeaddrinfo}
procedure freeaddrinfo(pAddrInfo: PAddrInfoA); stdcall;
{$EXTERNALSYM FreeAddrInfoA}
procedure FreeAddrInfoA(pAddrInfo: PAddrInfoA); stdcall;
{$EXTERNALSYM getnameinfo}
function getnameinfo(pSockaddr: PSockAddr; SockaddrLength: socklen_t;
  pNodeBuffer: PAnsiChar; NodeBufferSize: DWORD; pServiceBuffer: PAnsiChar;
  ServiceBufferSize: DWORD; Flags: Integer): Integer; stdcall;
{$EXTERNALSYM GetNameInfoA}
function GetNameInfoA(pSockaddr: PSockAddr; SockaddrLength: socklen_t;
  pNodeBuffer: PAnsiChar; NodeBufferSize: DWORD; pServiceBuffer: PAnsiChar;
  ServiceBufferSize: DWORD; Flags: Integer): Integer; stdcall;

{ Bound at run time (Windows XP SP2). When missing: GetAddrInfoW and
  GetNameInfoW return WSAVERNOTSUPPORTED; FreeAddrInfoW does nothing. }
{$EXTERNALSYM GetAddrInfoW}
function GetAddrInfoW(pNodeName, pServiceName: PWideChar; pHints: PAddrInfoW;
  var ppResult: PAddrInfoW): Integer; stdcall;
{$EXTERNALSYM FreeAddrInfoW}
procedure FreeAddrInfoW(pAddrInfo: PAddrInfoW); stdcall;
{$EXTERNALSYM GetNameInfoW}
function GetNameInfoW(pSockaddr: PSockAddr; SockaddrLength: socklen_t;
  pNodeBuffer: PWideChar; NodeBufferSize: DWORD; pServiceBuffer: PWideChar;
  ServiceBufferSize: DWORD; Flags: Integer): Integer; stdcall;

{ ====== Functions: Windows Vista and later (bound at run time) ============ }

{ Text to binary address (pAddrBuf receives an in_addr or in6_addr). Returns
  1, 0 for an invalid string, or SOCKET_ERROR; when missing, SOCKET_ERROR.
  InetPton and InetPtonA are inet_pton. }
{$EXTERNALSYM inet_pton}
function inet_pton(Family: Integer; pszAddrString: PAnsiChar; pAddrBuf: Pointer): Integer; stdcall;
{$EXTERNALSYM InetPtonA}
function InetPtonA(Family: Integer; pszAddrString: PAnsiChar; pAddrBuf: Pointer): Integer; stdcall;
{$EXTERNALSYM InetPtonW}
function InetPtonW(Family: Integer; pszAddrString: PWideChar; pAddrBuf: Pointer): Integer; stdcall;
{$EXTERNALSYM InetPton}
function InetPton(Family: Integer; pszAddrString: PAnsiChar; pAddrBuf: Pointer): Integer; stdcall;

{ Binary address (in_addr or in6_addr) to text; StringBufSize in characters
  (INET_ADDRSTRLEN, INET6_ADDRSTRLEN). Returns pStringBuf, or nil on failure
  and when missing. InetNtop and InetNtopA are inet_ntop. }
{$EXTERNALSYM inet_ntop}
function inet_ntop(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
  StringBufSize: ULONG_PTR): PAnsiChar; stdcall;
{$EXTERNALSYM InetNtopA}
function InetNtopA(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
  StringBufSize: ULONG_PTR): PAnsiChar; stdcall;
{$EXTERNALSYM InetNtopW}
function InetNtopW(Family: Integer; pAddr: Pointer; pStringBuf: PWideChar;
  StringBufSize: ULONG_PTR): PWideChar; stdcall;
{$EXTERNALSYM InetNtop}
function InetNtop(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
  StringBufSize: ULONG_PTR): PAnsiChar; stdcall;

{ Returns the number of entries with a non-zero revents, 0 on timeout
  (timeout in ms, -1 waits forever), or SOCKET_ERROR; when missing,
  SOCKET_ERROR. }
{$EXTERNALSYM WSAPoll}
function WSAPoll(fdArray: PWSAPollFD; fds: ULONG; timeout: Integer): Integer; stdcall;

{ Returns 0 or an error code; the list is freed with FreeAddrInfoExW. When
  missing: GetAddrInfoExW returns WSAVERNOTSUPPORTED, FreeAddrInfoExW does
  nothing. }
{$EXTERNALSYM GetAddrInfoExW}
function GetAddrInfoExW(pName, pServiceName: PWideChar; dwNameSpace: DWORD; lpNspId: PGUID;
  hints: PAddrInfoExW; var ppResult: PAddrInfoExW; timeout: PTimeVal;
  lpOverlapped: POverlapped; lpCompletionRoutine: LPLOOKUPSERVICE_COMPLETION_ROUTINE;
  lpHandle: PHandle): Integer; stdcall;
{$EXTERNALSYM FreeAddrInfoExW}
procedure FreeAddrInfoExW(pAddrInfoEx: PAddrInfoExW); stdcall;

{ Resolves nodename / servicename and connects s (an unbound AF_INET6 socket
  with IPV6_V6ONLY = 0 reaches IPv4 and IPv6 hosts). Returns False on
  failure and when missing. WSAConnectByName is WSAConnectByNameA. }
{$EXTERNALSYM WSAConnectByNameA}
function WSAConnectByNameA(s: TSocket; nodename, servicename: PAnsiChar;
  LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
  RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
{$EXTERNALSYM WSAConnectByNameW}
function WSAConnectByNameW(s: TSocket; nodename, servicename: PWideChar;
  LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
  RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
{$EXTERNALSYM WSAConnectByName}
function WSAConnectByName(s: TSocket; nodename, servicename: PAnsiChar;
  LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
  RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;

{ Sends lpMsg (datagram and raw sockets). Returns 0 or SOCKET_ERROR; when
  missing, SOCKET_ERROR. }
{$EXTERNALSYM WSASendMsg}
function WSASendMsg(Handle: TSocket; lpMsg: PWSAMsg; dwFlags: DWORD;
  lpNumberOfBytesSent: PDWORD; lpOverlapped: PWSAOverlapped;
  lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;

{ ====== Macros ============================================================ }

{ fd_set manipulation, as the macros of winsock2.h. FD_SET does nothing when
  the set already holds FD_SETSIZE sockets. }
{$EXTERNALSYM FD_CLR}
procedure FD_CLR(Socket: TSocket; var FDSet: TFDSet);
{$EXTERNALSYM FD_SET}
procedure FD_SET(Socket: TSocket; var FDSet: TFDSet);
{$EXTERNALSYM FD_ZERO}
procedure FD_ZERO(var FDSet: TFDSet);
{$EXTERNALSYM FD_ISSET}
function FD_ISSET(Socket: TSocket; var FDSet: TFDSet): Boolean;

{ Message parameters of WSAAsyncSelect and WSAAsyncGetXByY }
{$EXTERNALSYM WSAMAKEASYNCREPLY}
function WSAMAKEASYNCREPLY(buflen, error: Word): Longint;
{$EXTERNALSYM WSAMAKESELECTREPLY}
function WSAMAKESELECTREPLY(event, error: Word): Longint;
{$EXTERNALSYM WSAGETASYNCBUFLEN}
function WSAGETASYNCBUFLEN(lParam: LPARAM): Word;
{$EXTERNALSYM WSAGETASYNCERROR}
function WSAGETASYNCERROR(lParam: LPARAM): Word;
{$EXTERNALSYM WSAGETSELECTEVENT}
function WSAGETSELECTEVENT(lParam: LPARAM): Word;
{$EXTERNALSYM WSAGETSELECTERROR}
function WSAGETSELECTERROR(lParam: LPARAM): Word;

{ Control data of WSAMSG (ws2def.h). On x86 headers and data are aligned to
  4 bytes. WSA_CMSG_NXTHDR(msg, nil) is WSA_CMSG_FIRSTHDR(msg); both return
  nil after the last object. }
{$EXTERNALSYM WSA_CMSGHDR_ALIGN}
function WSA_CMSGHDR_ALIGN(length: ULONG_PTR): ULONG_PTR;
{$EXTERNALSYM WSA_CMSGDATA_ALIGN}
function WSA_CMSGDATA_ALIGN(length: ULONG_PTR): ULONG_PTR;
{$EXTERNALSYM WSA_CMSG_FIRSTHDR}
function WSA_CMSG_FIRSTHDR(msg: PWSAMsg): PWSACMsgHdr;
{$EXTERNALSYM WSA_CMSG_NXTHDR}
function WSA_CMSG_NXTHDR(msg: PWSAMsg; cmsg: PWSACMsgHdr): PWSACMsgHdr;
{$EXTERNALSYM WSA_CMSG_DATA}
function WSA_CMSG_DATA(cmsg: PWSACMsgHdr): Pointer;
{$EXTERNALSYM WSA_CMSG_SPACE}
function WSA_CMSG_SPACE(length: ULONG_PTR): ULONG_PTR;
{$EXTERNALSYM WSA_CMSG_LEN}
function WSA_CMSG_LEN(length: ULONG_PTR): ULONG_PTR;

implementation

const
  ws2_32 = 'ws2_32.dll';

{ ---- statically bound (exported by ws2_32.dll on Windows XP) ---- }

function accept; external ws2_32 name 'accept';
function bind; external ws2_32 name 'bind';
function closesocket; external ws2_32 name 'closesocket';
function connect; external ws2_32 name 'connect';
function ioctlsocket; external ws2_32 name 'ioctlsocket';
function getpeername; external ws2_32 name 'getpeername';
function getsockname; external ws2_32 name 'getsockname';
function getsockopt; external ws2_32 name 'getsockopt';
function htonl; external ws2_32 name 'htonl';
function htons; external ws2_32 name 'htons';
function inet_addr; external ws2_32 name 'inet_addr';
function inet_ntoa; external ws2_32 name 'inet_ntoa';
function listen; external ws2_32 name 'listen';
function ntohl; external ws2_32 name 'ntohl';
function ntohs; external ws2_32 name 'ntohs';
function recv; external ws2_32 name 'recv';
function recvfrom; external ws2_32 name 'recvfrom';
function select; external ws2_32 name 'select';
function send; external ws2_32 name 'send';
function sendto; external ws2_32 name 'sendto';
function setsockopt; external ws2_32 name 'setsockopt';
function shutdown; external ws2_32 name 'shutdown';
function socket; external ws2_32 name 'socket';
function gethostbyaddr; external ws2_32 name 'gethostbyaddr';
function gethostbyname; external ws2_32 name 'gethostbyname';
function gethostname; external ws2_32 name 'gethostname';
function getservbyport; external ws2_32 name 'getservbyport';
function getservbyname; external ws2_32 name 'getservbyname';
function getprotobynumber; external ws2_32 name 'getprotobynumber';
function getprotobyname; external ws2_32 name 'getprotobyname';

function WSAStartup; external ws2_32 name 'WSAStartup';
function WSACleanup; external ws2_32 name 'WSACleanup';
procedure WSASetLastError; external ws2_32 name 'WSASetLastError';
function WSAGetLastError; external ws2_32 name 'WSAGetLastError';
function WSAIsBlocking; external ws2_32 name 'WSAIsBlocking';
function WSAUnhookBlockingHook; external ws2_32 name 'WSAUnhookBlockingHook';
function WSASetBlockingHook; external ws2_32 name 'WSASetBlockingHook';
function WSACancelBlockingCall; external ws2_32 name 'WSACancelBlockingCall';
function WSAAsyncGetServByName; external ws2_32 name 'WSAAsyncGetServByName';
function WSAAsyncGetServByPort; external ws2_32 name 'WSAAsyncGetServByPort';
function WSAAsyncGetProtoByName; external ws2_32 name 'WSAAsyncGetProtoByName';
function WSAAsyncGetProtoByNumber; external ws2_32 name 'WSAAsyncGetProtoByNumber';
function WSAAsyncGetHostByName; external ws2_32 name 'WSAAsyncGetHostByName';
function WSAAsyncGetHostByAddr; external ws2_32 name 'WSAAsyncGetHostByAddr';
function WSACancelAsyncRequest; external ws2_32 name 'WSACancelAsyncRequest';
function WSAAsyncSelect; external ws2_32 name 'WSAAsyncSelect';
function WSAAccept; external ws2_32 name 'WSAAccept';
function WSACloseEvent; external ws2_32 name 'WSACloseEvent';
function WSAConnect; external ws2_32 name 'WSAConnect';
function WSACreateEvent; external ws2_32 name 'WSACreateEvent';
function WSADuplicateSocketA; external ws2_32 name 'WSADuplicateSocketA';
function WSADuplicateSocketW; external ws2_32 name 'WSADuplicateSocketW';
function WSADuplicateSocket; external ws2_32 name 'WSADuplicateSocketA';
function WSAEnumNetworkEvents; external ws2_32 name 'WSAEnumNetworkEvents';
function WSAEnumProtocolsA; external ws2_32 name 'WSAEnumProtocolsA';
function WSAEnumProtocolsW; external ws2_32 name 'WSAEnumProtocolsW';
function WSAEnumProtocols; external ws2_32 name 'WSAEnumProtocolsA';
function WSAEventSelect; external ws2_32 name 'WSAEventSelect';
function WSAGetOverlappedResult; external ws2_32 name 'WSAGetOverlappedResult';
function WSAHtonl; external ws2_32 name 'WSAHtonl';
function WSAHtons; external ws2_32 name 'WSAHtons';
function WSAIoctl; external ws2_32 name 'WSAIoctl';
function WSAJoinLeaf; external ws2_32 name 'WSAJoinLeaf';
function WSANtohl; external ws2_32 name 'WSANtohl';
function WSANtohs; external ws2_32 name 'WSANtohs';
function WSARecv; external ws2_32 name 'WSARecv';
function WSARecvDisconnect; external ws2_32 name 'WSARecvDisconnect';
function WSARecvFrom; external ws2_32 name 'WSARecvFrom';
function WSAResetEvent; external ws2_32 name 'WSAResetEvent';
function WSASend; external ws2_32 name 'WSASend';
function WSASendDisconnect; external ws2_32 name 'WSASendDisconnect';
function WSASendTo; external ws2_32 name 'WSASendTo';
function WSASetEvent; external ws2_32 name 'WSASetEvent';
function WSASocketA; external ws2_32 name 'WSASocketA';
function WSASocketW; external ws2_32 name 'WSASocketW';
function WSASocket; external ws2_32 name 'WSASocketA';
function WSAWaitForMultipleEvents; external ws2_32 name 'WSAWaitForMultipleEvents';
function WSAAddressToStringA; external ws2_32 name 'WSAAddressToStringA';
function WSAAddressToStringW; external ws2_32 name 'WSAAddressToStringW';
function WSAAddressToString; external ws2_32 name 'WSAAddressToStringA';
function WSAStringToAddressA; external ws2_32 name 'WSAStringToAddressA';
function WSAStringToAddressW; external ws2_32 name 'WSAStringToAddressW';
function WSAStringToAddress; external ws2_32 name 'WSAStringToAddressA';
function __WSAFDIsSet; external ws2_32 name '__WSAFDIsSet';

function getaddrinfo; external ws2_32 name 'getaddrinfo';
function GetAddrInfoA; external ws2_32 name 'getaddrinfo';
procedure freeaddrinfo; external ws2_32 name 'freeaddrinfo';
procedure FreeAddrInfoA; external ws2_32 name 'freeaddrinfo';
function getnameinfo; external ws2_32 name 'getnameinfo';
function GetNameInfoA; external ws2_32 name 'getnameinfo';

{ ---- run-time binding ---- }

var
  Ws2Module: HMODULE;
  Ws2Tried: Boolean;

{ Loads ws2_32.dll once, by full path from the system directory (no
  search-order planting), keeps the reference for the life of the process
  and looks up an export. A function pointer is cached once found. }
function GetWs2Proc(var Proc: Pointer; Name: PAnsiChar): Boolean;
var
  Path: array[0..MAX_PATH + 16] of AnsiChar;
  Len: UINT;
begin
  if Proc = nil then
  begin
    if not Ws2Tried then
    begin
      Len := GetSystemDirectoryA(Path, MAX_PATH);
      if (Len > 0) and (Len < MAX_PATH) then
      begin
        lstrcatA(Path, '\');
        lstrcatA(Path, ws2_32);
        Ws2Module := LoadLibraryA(Path);
      end;
      if Ws2Module = 0 then
        Ws2Module := GetModuleHandleA(ws2_32);
      Ws2Tried := True;
    end;
    if Ws2Module <> 0 then
      Proc := GetProcAddress(Ws2Module, Name);
  end;
  Result := Proc <> nil;
end;

{ The failure of a function that ws2_32.dll does not export: sets
  WSAGetLastError to WSAVERNOTSUPPORTED and returns SOCKET_ERROR. }
function NotSupported: Integer;
begin
  WSASetLastError(WSAVERNOTSUPPORTED);
  Result := SOCKET_ERROR;
end;

type
  TFnGetAddrInfoW = function(pNodeName, pServiceName: PWideChar; pHints: PAddrInfoW;
    var ppResult: PAddrInfoW): Integer; stdcall;
  TFnFreeAddrInfoW = procedure(pAddrInfo: PAddrInfoW); stdcall;
  TFnGetNameInfoW = function(pSockaddr: PSockAddr; SockaddrLength: socklen_t;
    pNodeBuffer: PWideChar; NodeBufferSize: DWORD; pServiceBuffer: PWideChar;
    ServiceBufferSize: DWORD; Flags: Integer): Integer; stdcall;
  TFnInetPtonA = function(Family: Integer; pszAddrString: PAnsiChar;
    pAddrBuf: Pointer): Integer; stdcall;
  TFnInetPtonW = function(Family: Integer; pszAddrString: PWideChar;
    pAddrBuf: Pointer): Integer; stdcall;
  TFnInetNtopA = function(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
    StringBufSize: ULONG_PTR): PAnsiChar; stdcall;
  TFnInetNtopW = function(Family: Integer; pAddr: Pointer; pStringBuf: PWideChar;
    StringBufSize: ULONG_PTR): PWideChar; stdcall;
  TFnWSAPoll = function(fdArray: PWSAPollFD; fds: ULONG; timeout: Integer): Integer; stdcall;
  TFnGetAddrInfoExW = function(pName, pServiceName: PWideChar; dwNameSpace: DWORD;
    lpNspId: PGUID; hints: PAddrInfoExW; var ppResult: PAddrInfoExW; timeout: PTimeVal;
    lpOverlapped: POverlapped; lpCompletionRoutine: LPLOOKUPSERVICE_COMPLETION_ROUTINE;
    lpHandle: PHandle): Integer; stdcall;
  TFnFreeAddrInfoExW = procedure(pAddrInfoEx: PAddrInfoExW); stdcall;
  TFnWSAConnectByNameA = function(s: TSocket; nodename, servicename: PAnsiChar;
    LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
    RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
  TFnWSAConnectByNameW = function(s: TSocket; nodename, servicename: PWideChar;
    LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
    RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
  TFnWSASendMsg = function(Handle: TSocket; lpMsg: PWSAMsg; dwFlags: DWORD;
    lpNumberOfBytesSent: PDWORD; lpOverlapped: PWSAOverlapped;
    lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;

var
  GetAddrInfoWProc: Pointer;
  FreeAddrInfoWProc: Pointer;
  GetNameInfoWProc: Pointer;
  InetPtonAProc: Pointer;
  InetPtonWProc: Pointer;
  InetNtopAProc: Pointer;
  InetNtopWProc: Pointer;
  WSAPollProc: Pointer;
  GetAddrInfoExWProc: Pointer;
  FreeAddrInfoExWProc: Pointer;
  WSAConnectByNameAProc: Pointer;
  WSAConnectByNameWProc: Pointer;
  WSASendMsgProc: Pointer;

{ ---- Windows XP SP2 ---- }

function GetAddrInfoW(pNodeName, pServiceName: PWideChar; pHints: PAddrInfoW;
  var ppResult: PAddrInfoW): Integer; stdcall;
begin
  if GetWs2Proc(GetAddrInfoWProc, 'GetAddrInfoW') then
    Result := TFnGetAddrInfoW(GetAddrInfoWProc)(pNodeName, pServiceName, pHints, ppResult)
  else
  begin
    ppResult := nil;
    NotSupported;
    Result := WSAVERNOTSUPPORTED;
  end;
end;

procedure FreeAddrInfoW(pAddrInfo: PAddrInfoW); stdcall;
begin
  if GetWs2Proc(FreeAddrInfoWProc, 'FreeAddrInfoW') then
    TFnFreeAddrInfoW(FreeAddrInfoWProc)(pAddrInfo);
end;

function GetNameInfoW(pSockaddr: PSockAddr; SockaddrLength: socklen_t;
  pNodeBuffer: PWideChar; NodeBufferSize: DWORD; pServiceBuffer: PWideChar;
  ServiceBufferSize: DWORD; Flags: Integer): Integer; stdcall;
begin
  if GetWs2Proc(GetNameInfoWProc, 'GetNameInfoW') then
    Result := TFnGetNameInfoW(GetNameInfoWProc)(pSockaddr, SockaddrLength, pNodeBuffer,
      NodeBufferSize, pServiceBuffer, ServiceBufferSize, Flags)
  else
  begin
    NotSupported;
    Result := WSAVERNOTSUPPORTED;
  end;
end;

{ ---- Windows Vista ---- }

function inet_pton(Family: Integer; pszAddrString: PAnsiChar; pAddrBuf: Pointer): Integer; stdcall;
begin
  if GetWs2Proc(InetPtonAProc, 'inet_pton') then
    Result := TFnInetPtonA(InetPtonAProc)(Family, pszAddrString, pAddrBuf)
  else
    Result := NotSupported;
end;

function InetPtonA(Family: Integer; pszAddrString: PAnsiChar; pAddrBuf: Pointer): Integer; stdcall;
begin
  Result := inet_pton(Family, pszAddrString, pAddrBuf);
end;

function InetPtonW(Family: Integer; pszAddrString: PWideChar; pAddrBuf: Pointer): Integer; stdcall;
begin
  if GetWs2Proc(InetPtonWProc, 'InetPtonW') then
    Result := TFnInetPtonW(InetPtonWProc)(Family, pszAddrString, pAddrBuf)
  else
    Result := NotSupported;
end;

function InetPton(Family: Integer; pszAddrString: PAnsiChar; pAddrBuf: Pointer): Integer; stdcall;
begin
  Result := inet_pton(Family, pszAddrString, pAddrBuf);
end;

function inet_ntop(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
  StringBufSize: ULONG_PTR): PAnsiChar; stdcall;
begin
  if GetWs2Proc(InetNtopAProc, 'inet_ntop') then
    Result := TFnInetNtopA(InetNtopAProc)(Family, pAddr, pStringBuf, StringBufSize)
  else
  begin
    NotSupported;
    Result := nil;
  end;
end;

function InetNtopA(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
  StringBufSize: ULONG_PTR): PAnsiChar; stdcall;
begin
  Result := inet_ntop(Family, pAddr, pStringBuf, StringBufSize);
end;

function InetNtopW(Family: Integer; pAddr: Pointer; pStringBuf: PWideChar;
  StringBufSize: ULONG_PTR): PWideChar; stdcall;
begin
  if GetWs2Proc(InetNtopWProc, 'InetNtopW') then
    Result := TFnInetNtopW(InetNtopWProc)(Family, pAddr, pStringBuf, StringBufSize)
  else
  begin
    NotSupported;
    Result := nil;
  end;
end;

function InetNtop(Family: Integer; pAddr: Pointer; pStringBuf: PAnsiChar;
  StringBufSize: ULONG_PTR): PAnsiChar; stdcall;
begin
  Result := inet_ntop(Family, pAddr, pStringBuf, StringBufSize);
end;

function WSAPoll(fdArray: PWSAPollFD; fds: ULONG; timeout: Integer): Integer; stdcall;
begin
  if GetWs2Proc(WSAPollProc, 'WSAPoll') then
    Result := TFnWSAPoll(WSAPollProc)(fdArray, fds, timeout)
  else
    Result := NotSupported;
end;

function GetAddrInfoExW(pName, pServiceName: PWideChar; dwNameSpace: DWORD; lpNspId: PGUID;
  hints: PAddrInfoExW; var ppResult: PAddrInfoExW; timeout: PTimeVal;
  lpOverlapped: POverlapped; lpCompletionRoutine: LPLOOKUPSERVICE_COMPLETION_ROUTINE;
  lpHandle: PHandle): Integer; stdcall;
begin
  if GetWs2Proc(GetAddrInfoExWProc, 'GetAddrInfoExW') then
    Result := TFnGetAddrInfoExW(GetAddrInfoExWProc)(pName, pServiceName, dwNameSpace,
      lpNspId, hints, ppResult, timeout, lpOverlapped, lpCompletionRoutine, lpHandle)
  else
  begin
    ppResult := nil;
    NotSupported;
    Result := WSAVERNOTSUPPORTED;
  end;
end;

procedure FreeAddrInfoExW(pAddrInfoEx: PAddrInfoExW); stdcall;
begin
  if GetWs2Proc(FreeAddrInfoExWProc, 'FreeAddrInfoExW') then
    TFnFreeAddrInfoExW(FreeAddrInfoExWProc)(pAddrInfoEx);
end;

function WSAConnectByNameA(s: TSocket; nodename, servicename: PAnsiChar;
  LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
  RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
begin
  if GetWs2Proc(WSAConnectByNameAProc, 'WSAConnectByNameA') then
    Result := TFnWSAConnectByNameA(WSAConnectByNameAProc)(s, nodename, servicename,
      LocalAddressLength, LocalAddress, RemoteAddressLength, RemoteAddress, timeout, Reserved)
  else
  begin
    NotSupported;
    Result := False;
  end;
end;

function WSAConnectByNameW(s: TSocket; nodename, servicename: PWideChar;
  LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
  RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
begin
  if GetWs2Proc(WSAConnectByNameWProc, 'WSAConnectByNameW') then
    Result := TFnWSAConnectByNameW(WSAConnectByNameWProc)(s, nodename, servicename,
      LocalAddressLength, LocalAddress, RemoteAddressLength, RemoteAddress, timeout, Reserved)
  else
  begin
    NotSupported;
    Result := False;
  end;
end;

function WSAConnectByName(s: TSocket; nodename, servicename: PAnsiChar;
  LocalAddressLength: PDWORD; LocalAddress: PSockAddr; RemoteAddressLength: PDWORD;
  RemoteAddress: PSockAddr; timeout: PTimeVal; Reserved: PWSAOverlapped): BOOL; stdcall;
begin
  Result := WSAConnectByNameA(s, nodename, servicename, LocalAddressLength, LocalAddress,
    RemoteAddressLength, RemoteAddress, timeout, Reserved);
end;

function WSASendMsg(Handle: TSocket; lpMsg: PWSAMsg; dwFlags: DWORD;
  lpNumberOfBytesSent: PDWORD; lpOverlapped: PWSAOverlapped;
  lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
begin
  if GetWs2Proc(WSASendMsgProc, 'WSASendMsg') then
    Result := TFnWSASendMsg(WSASendMsgProc)(Handle, lpMsg, dwFlags, lpNumberOfBytesSent,
      lpOverlapped, lpCompletionRoutine)
  else
    Result := NotSupported;
end;

{ ---- macros ---- }

procedure FD_CLR(Socket: TSocket; var FDSet: TFDSet);
var
  I: Cardinal;
begin
  I := 0;
  while I < FDSet.fd_count do
  begin
    if FDSet.fd_array[I] = Socket then
    begin
      while I < FDSet.fd_count - 1 do
      begin
        FDSet.fd_array[I] := FDSet.fd_array[I + 1];
        Inc(I);
      end;
      Dec(FDSet.fd_count);
      Break;
    end;
    Inc(I);
  end;
end;

procedure FD_SET(Socket: TSocket; var FDSet: TFDSet);
var
  I: Cardinal;
begin
  I := 0;
  while (I < FDSet.fd_count) and (FDSet.fd_array[I] <> Socket) do
    Inc(I);
  if (I = FDSet.fd_count) and (FDSet.fd_count < FD_SETSIZE) then
  begin
    FDSet.fd_array[I] := Socket;
    Inc(FDSet.fd_count);
  end;
end;

procedure FD_ZERO(var FDSet: TFDSet);
begin
  FDSet.fd_count := 0;
end;

function FD_ISSET(Socket: TSocket; var FDSet: TFDSet): Boolean;
begin
  Result := __WSAFDIsSet(Socket, FDSet) <> 0;
end;

function WSAMAKEASYNCREPLY(buflen, error: Word): Longint;
begin
  Result := Longint(DWORD(buflen) or (DWORD(error) shl 16));
end;

function WSAMAKESELECTREPLY(event, error: Word): Longint;
begin
  Result := Longint(DWORD(event) or (DWORD(error) shl 16));
end;

function WSAGETASYNCBUFLEN(lParam: LPARAM): Word;
begin
  Result := Word(DWORD(lParam));
end;

function WSAGETASYNCERROR(lParam: LPARAM): Word;
begin
  Result := Word(DWORD(lParam) shr 16);
end;

function WSAGETSELECTEVENT(lParam: LPARAM): Word;
begin
  Result := Word(DWORD(lParam));
end;

function WSAGETSELECTERROR(lParam: LPARAM): Word;
begin
  Result := Word(DWORD(lParam) shr 16);
end;

{ TYPE_ALIGNMENT(WSACMSGHDR) and MAX_NATURAL_ALIGNMENT are 4 on x86 }

function WSA_CMSGHDR_ALIGN(length: ULONG_PTR): ULONG_PTR;
begin
  Result := (length + 3) and not ULONG_PTR(3);
end;

function WSA_CMSGDATA_ALIGN(length: ULONG_PTR): ULONG_PTR;
begin
  Result := (length + 3) and not ULONG_PTR(3);
end;

function WSA_CMSG_FIRSTHDR(msg: PWSAMsg): PWSACMsgHdr;
begin
  if msg^.Control.len >= SizeOf(WSACMSGHDR) then
    Result := PWSACMsgHdr(msg^.Control.buf)
  else
    Result := nil;
end;

function WSA_CMSG_NXTHDR(msg: PWSAMsg; cmsg: PWSACMsgHdr): PWSACMsgHdr;
var
  Next: ULONG_PTR;
begin
  if cmsg = nil then
    Result := WSA_CMSG_FIRSTHDR(msg)
  else
  begin
    Next := ULONG_PTR(cmsg) + WSA_CMSGHDR_ALIGN(cmsg^.cmsg_len);
    if Next + SizeOf(WSACMSGHDR) > ULONG_PTR(msg^.Control.buf) + msg^.Control.len then
      Result := nil
    else
      Result := PWSACMsgHdr(Next);
  end;
end;

function WSA_CMSG_DATA(cmsg: PWSACMsgHdr): Pointer;
begin
  Result := Pointer(ULONG_PTR(cmsg) + WSA_CMSGDATA_ALIGN(SizeOf(WSACMSGHDR)));
end;

function WSA_CMSG_SPACE(length: ULONG_PTR): ULONG_PTR;
begin
  Result := WSA_CMSGDATA_ALIGN(SizeOf(WSACMSGHDR) + WSA_CMSGHDR_ALIGN(length));
end;

function WSA_CMSG_LEN(length: ULONG_PTR): ULONG_PTR;
begin
  Result := WSA_CMSGDATA_ALIGN(SizeOf(WSACMSGHDR)) + length;
end;

end.
