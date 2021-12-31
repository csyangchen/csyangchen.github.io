---
title: Golang 读写锁相关问题一则
---

# 背景

线上一个服务发现, 出现了逻辑 panic 之后, goroutine 堆积, 导致请求失败率飙升.

定位到请求处理路劲如下代码段:

    var mu sync.RWMutex
    ...
    mu.RLock()
    readFuncThatMightPanic()
    mu.Unlock()

此外有单独更新线程尝试`mu.Lock()`并更新相关保护资源.

修复了panic问题之后, 百思不得解, 为什么会导致请求gouroutine堆积.
判断是panic后, `Unlock`自然不会执行. 此时`mu`还是读锁保护状态, 后续的请求应该是能够继续获得读锁并正常处理流程的.
觉得最多会写入线程堵塞在`Lock`处.

后来写了DEMO验证了想当然错了, Golang里面的读写锁是写优先的, 写会阻塞后续的读请求.

# `sync.RWMutex` 实现机制

    type RWMutex struct {
        w Mutex // 写锁
        writerSem uint32 // 写信号量
        readerSem uint32 // 读信号量
        readerCount int32 // 等待读者数目, <0 表示有写等待或者写锁
        readerWait int32 // 当前等待写锁等待的读者数目
    }

标准库代码就不粘贴了, 说下思路.
- 复用`sync.Mutex`作为写锁
- 利用了原子操作`atomic.Add`来实现计数器的原子操作, 更新 readerCount / readerWait.
- 需要操作系统提供信号量的基本原语 (runtime_Semacquire/runtime_Semrelease).

用一个很大的标记数`rwmutexMaxReaders`用来标记是否有等待的写请求.

1. RLock: readerCount++, 如果>=0, 则直接继续. 否则说明有写锁或者写等待, 等待读信号量 (Unlock).
2. RUnlock:
   a. readerCount--, 如果读者数>=0, 不做任何操作.
   b. 否则, 说明有写等待, readerWait--. 如果=0, 说明是最后一个被等待的读者, 触发写信号量 (Lock).
3. Lock:
   a. 获得写锁, 如果已经有写锁, 则等待 (4b). 之后就是和读锁交互的问题
   b. readerCount-=rwmutexMaxReaders, 用来占住位置, 挡住住后续的RLock.
   c. 判断当前readerCount. 如果>0, 加到readerWait.
   d. 如果readerWait不为0 (应该只有>0的情况), 说明还有读者没离去. 等写信号量 (RUnlock).
   e. 否则(readerWait=0), 说明读者在b, c两步中间已经全部离去, 安全获得写锁, 不用等写信号量了.
4. Unlock:
   a. readerCount+rwmutexMaxReaders, 一定是>=0的, 表示等待的读者数目, 分别触发读信号量 (RLock).
   b. 释放写锁 (3a)

四个操作搅在一起, 需要一起来看.



# 总结

- 不用`defer`释放资源的情况下, 要确保 panic free
- 需要正确理解读写锁的优先级问题和实现机制

# Reference

- <https://medium.com/golangspec/sync-rwmutex-ca6c6c3208a0>
