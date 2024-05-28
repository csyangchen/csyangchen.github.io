---
title: Golang 与 Erlang 并发模式探讨
---

# concurrency vs parallelism

- concurrency structuring a program as independently executing components
- parallelism executing calculations in parallel for efficiency on multiple CPUs

# CSP vs Actor

Do not communicate by sharing memory; instead, share memory by communicating.

Erlang 优点

- 注册发现机制
- supervisor 机制
- 内置的跨节点通讯能力
- 鲁棒性, 单个挂掉不影响其他

## CSP in Erlang

## Actor in Golang

## gen_server in Golang

# 消息队列

Erlang: 无界消息队列, 消息发送时发生拷贝; 匹配特性, 不按照发送顺序处理.

Golang: 有界消息队列, 不发生拷贝, 保证FIFO顺序.

## call vs cast 语义

- call: 要求发生回调, 同步调用, RPC
- cast: 单纯消息通知, 消息队列

Erlang call

- cast msg with secret
- recv reply with given secret, ignore all other inflight reply

对象用两个unbuffered channel, 一个负责收, 一个负责发.

	target.Cin <- msg
	reply <- target.Cout
	
或者请求里面自带一个回传channel, 发给对方后, 阻塞监听

	target.Cin <- msg
	for reply := range msg.Cout {
		// handle reply
	}
	
cast语义的话, 只要把消息发出去就可以了. 不过为了回传, 消息里面还是需要有能够表示调用者的信息.
这里暴露一个公共的channel就可以了.

## 如何安全的往一个channel里面发消息

- <http://www.jtolds.com/writing/2016/03/go-channels-are-bad-and-you-should-feel-bad/>

