---
title: Golang服务优雅关闭连接
tags: golang
---

# 问题背景

作为一个负责任的接口服务, 在关闭的时候, 除了关闭监听入口, 需要将"在途"(inflight)的请求处理完成, 以确保服务的可用性, 并主动关闭TCP连接, 以触发客户端重连/重试. 类比: 银行等很多场所, 5点下班, 但是4点开始就不接客了.

线上一个监听多个端口的服务(HTTP接口 + 模拟成redis的接口), 通过LB层 (HAProxy) 提供客户端请求访问.
在服务扩容/缩容的过程中, 客户端记录到了连接异常断掉的问题 (表征为EOF错误). 初步定位时服务关闭的时候没有主动关掉所有服务连接导致.
对于HTTP接口, 我们做了优雅关闭, 但是redis接口的服务是一个野的`go serve`启动的, 退出的时候没有主动关闭机制, 导致瞬时很多客户端请求失败.
为了实现redis接口服务的优雅关闭, 需要参CHAO考XI下标准库的实现方式.

# go http server 优雅关闭姿势

[Go 1.8](<https://golang.org/doc/go1.8#http_shutdown>) 之后添加了对于HTTP服务的优雅关闭支持, 在实际使用还是不是那么直接的.

最常用的 `http.ListenAndServe` 本身阻塞在请求监听中, 没办法同线程触发退出.

一种啰嗦的写法:

    server := &http.Server{...}

    // NOTE 这里不需要等待该线程退出, 因为 Shutdown 返回已经能够保证全部处理完了
    go func() {
        err := server.ListenAndServe()
        if err != http.ErrServerClosed {
            panic(err) // 为了捕获监听失败的错误
        }
    }

    // wait for server shut down signal
    ch := make(chan os.Signal)
    signal.Notify(ch, os.Interrupt)
    <-ch

    server.Shutdown(ctx)


能有个二段启动, 对于调用者来说比较方便.

    func ListenAndServe(addr string, handler http.Handler) error {
    	server := &http.Server{Addr: addr, Handler: handler}
    	ln, err := net.Listen("tcp", addr)
    	if err != nil {
    		return err
    	}
    	go server.Serve(ln)
    	return nil
    }

    server, err := ListenAndServe(addr, handler)
    if err != nil {
        panic(err)
    }
    defer server.Shutdown(ctx)

    // wait for server shut down signal


注意: 标准库实现里面对于`Listener`做了封装, 增加了TCP Keepalive相关设置, 避免被曝过多连接.

此外, 这种二段启动, 导致监听端口和启动服务逻辑在不同线程完成, 也许会导致被accept的连接不能被及时处理 ?

如果 `Shutdown` 由于超时失败, 安全点的做法感觉还是要调用下 `Close` 确保所有客户端连接都被关掉.

# go http server 优雅关闭实现机制

具体实现见 [`/src/net/http/server.go`](https://github.com/golang/go/blob/master/src/net/http/server.go).

每个连接创建的时候记录在一个字典 (`activeConn`) 中, 并在关闭连接的时候从字典中移除.

简单来说, HTTP是的一问一答协议.
每个连接有一个业务状态位, 在HTTP请求读取/构造完成后标记为 `StateActive`,
请求处理完毕后标记为 `StateIdle`, 并阻塞等待下一个请求读取上.

Close的操作:

1. 关掉所有监听的Listener, 确保不会有新的连接产生
2. 遍历连接字典, 直接关闭TCP连接.

Shutdown:

1. 同Close, 卸掉监听端口
2. 创建一个定时器轮询连接字典, 并关闭掉处于 `StateIdle` 状态的连接, 直到连接全部关闭, 或者超时.

如果关闭的时候没有在途请求处理, 那么`Close`和`Shutdown`是等效的, 这在QPS比较低的时候会比较普遍.

实现由于涉及多线程的问题, 代码处理的时候用了很多channel, mutex, 以及atomic操作, 看上去会比较啰嗦.

## 看代码时的一些问题记录

很多重要的变量如`done`, `activeConn` 是懒初始化的, 并考虑的线程安全. 应该是考虑到启动服务和关闭服务不在同一个线程.
也没有一个明确的类似constructor的地方导致的折衷吧.

为什么先关闭Listener, Listen报错的时候再判断是否Shutdown?
因为Listen是个阻塞操作, 且没有暴露出能够select channel的方式调用. 同理, 在请求处理的 for loop 里面, 不能够每次判断下是否需要退出.
因为主要阻塞在读取请求处了. 对于涉及到阻塞IO的关闭问题, 都可以参考来做: 暴力关掉底层连接, IO错误处理时判断下是否处于关闭阶段, 如果是退出.
例子: BRPOP消费redis队列的时候, 为了不丢消息的处理手法, 也许可以参考这种方式 (TODO 关了客户端连接但是消息在服务端已经被POP出来了咋整???).

`shutdownPollInterval` 注释里面说有更好的方式, 留作读者练习, WTF ??? 能够想到的办法, 是在每次连接设置为 `StateIdle` 时, 判断下是否处于关闭过程, 如果是, 直接退出当前请求处理的loop. 避免轮询忙等.
但这里就牵扯到另外一个问题: 如何在所有gourotine都退出的时候触发通知, 用一个 count down channel ??? 这个准确的前提得是确定没有新的连接产生.

# 服务退出模式

个人常写的消费者服务模式:

	done := make(chan struct{})
	var wg sync.WaitGroup
	for i := 0; i < 32; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-done:
					return
				default:
				}
				// work work
			}
		}()
	}

	time.Sleep(time.Second)
	close(done)
	wg.Wait()

当然理想情况下是以 channel 形式消费任务, 并关闭 channel 来触发 下游消费者退出, 干净!

    wg.Add(1)
    go func() {
        defer wg.Done()
        for msg := range inputStream {
            // work work
        }
    }

    close(inputStream)
    wg.Wait()

`sync.WaitGroup` 的缺点在于等待不好实现关闭超时机制. 开发中常会由于消费loop耗时较长, 没有及时检查退出状态, 导致整个关闭过程耗时较久, 或者不能正常退出. 改进办法是另外一个 反馈队列, 并记录到底有多少个消费者. 这个就是纯粹的基于消息队列的同步方式.

    done := make(chan struct{})
    exit := make(chan struct{})

    n := 32
    for i := 0; i < n; i++ {
        go func() {
            for {
                select {
                case <- done:
                    exit <- struct{}{}
                default:
                    //
                }
                // work work
            }
        }()
    }

    select {
    case <-ctx.Done():
        // timeout on shutdown
    case <-exit:
        n--
        if n == 0 {
            // ok shutdown
        }
    }

