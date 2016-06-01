tun2socks
=========
![](https://travis-ci.org/zhuhaow/tun2socks.svg?branch=master)

tun2socks is designed to work with the NetworkExtension framework available since
iOS 9 and OS X 10.11. It is based on the latest stable lwip with minimal
modification.

Usage
-----
Just read the comments in the Swift wrapper in `tun2socks/wrapper`.

You may be more interested in using [NEKit](https://github.com/zhuhaow/NEKit)
which wraps around tun2socks.

Only TCP is supported.

All other protocols (UDP, ICMP, IGMP, ...) will not be supported since they are stateless or can not be supported in NetworkExtension.

IPv6 support
------------
As of now, IPv6 is not supported since lwip 1.4 does not support dual stack.
IPv6 will be supported in the next major version of lwip.

 
