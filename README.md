tun2socks
=========
![](https://travis-ci.org/zhuhaow/tun2socks.svg?branch=master)
[![GitHub version](https://badge.fury.io/gh/zhuhaow%2Ftun2socks.svg)](https://badge.fury.io/gh/zhuhaow%2Ftun2socks)

tun2socks is designed to work with the NetworkExtension framework. It is based on the latest stable lwip with minimal modification.

Feature
-----
The whole stack is based on GCD which is efficient and fast.

Only TCP protocol is supported.

All other protocols (UDP, ICMP, IGMP, ...) will not be supported since they are stateless or can not be supported in NetworkExtension.

Usage
-----
Fully documented API reference can be found [here](https://zhuhaow.github.io/tun2socks/).

I recommend using [Carthage](https://github.com/Carthage/Carthage) to integrate tun2socks in your project by adding

```
github "zhuhaow/tun2socks"
```

to your `Cartfile`.

You may be more interested in using [NEKit](https://github.com/zhuhaow/NEKit) which wraps around tun2socks.

IPv6 support
------------
As of now, IPv6 is not supported since lwip 1.4 does not support dual stack.
IPv6 will be supported in the next major version of lwip.