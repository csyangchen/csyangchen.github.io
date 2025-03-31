---
title: Python并发网络编程
---

TODO https://www.v2ex.com/t/1110155#reply10

为什么要并发? 在等待中多做点有用的事情, 在不确定的世界中填满空虚的内心

业务场景:
- 爬虫系统 (抓取外部网站)
- WEB后端 (数据库查询代理)

主要瓶颈在于不可控的外部环节: 目标网站访问速度, 数据库查询耗时, 数据网络传输

坚守朴素的单进程模式, 通过队列系统 / 负载均衡等手段, 也可以撑到很高, 但是资源利用率太低

这里不考虑并行计算相关加速目的

对于可控系统, 首先优化单任务耗时解决来瓶颈问题, 如批量化等, 最后再考虑并发的手段!

# 进程 VS 线程 VS 协程

多进程 / multiprocessing
- 优点:
  - 充分隔离
  - 方便外部单独管理启停 (至少有个PID)
  - 编程心智负担相对简单
- 缺点:
  - 系统调度开销太大 / 内存资源
  - 数据同步需要通过MMAP等相对较重的机制

多线程 / multithreading
- 优点:
  - 对比多进程, 额外内存资源开销较小
  - 尤其对于PY程序, 由于各种依赖引入, 常态占用内存比较大, 百兆级别, 实际运行时额外申请内存占比极低, 同样资源多线程可以开到更多
  - 对于数据库等比较宝贵的内部资源链接, 可以通过跨线程复用方式, 显著减少目标系统的连接数及相关资源
  - 可以比较方便的做一些轻量的同步原语, 数据共享
- 缺点
  - 风险不隔离 / 一处逻辑挂了整个程序重启, 影响其他在途计算

共同的缺点:
操作系统层面调度, 中断过多, 内核态占比高, 无效计算占比高, 额外内存的开销, 导致单机可以多开的数量有上限.
因此需要用户态"线程", 及更轻量的任务调度机制

协程 / coroutine, co is for cooperative.
用户态的最小计算调度任务单元, 由于实际上是单个执行, 共享数据访问不需要加锁等手段保护. 一个任务的计算状态保存可以做到很小

# 网络编程模型

socket编程
- fork process or thread on new request / 一般系统编程/网络编程教学用例
- pooling, 进程/线程池, 减少创建销毁调度开销, 复用
  - 1 master + n worker 模式
  - master 管理 worker
  - worker 处理实际请求, 可能是master转交, 或者通过SO_REUSEPORT机制让操作系统分发
  - 每个worker可进一步做事件驱动逻辑, 多worker主要是为了跑多核实现并行

IO模型
- 同步/非同步 (synchronous / asynchronous)
  - 多线程编程模式: listen一个线程生成socket, worker线程池认领socket处理直到关闭
  - 单线程下的多路复用机制 (multiplexing)
    - select (FD_SETSIZE大小限制了上限) / poll
    - [epoll](https://man7.org/linux/man-pages/man7/epoll.7.html)
- 阻塞/非阻塞 (blocking / non-blocking)
  - ref call / cast 语义区别
  - 针对单个任务的IO而言的
  - [aio](https://man7.org/linux/man-pages/man7/aio.7.html)

# 事件驱动 (event loop)

事件 (event) 种类
- IO事件 / io multiplexing
- 信号 / signals
- 计时器: 心跳, 超时事件, 事件执行让出, 定期检查, 等

回调 = 对应事件的处理动作

注意, 非IO相关代码仍然是串行化执行的, 调度本身的检查计算开销损失, 因此并不能实现完全的线性加速

调度器 (scheduler), 可以是单线程, 也可以是多线程, 从事件任务队列中选取->执行->放回.

事件任务队列可以是每个调度器独有一个, 从而减少共享数据读写, 或者全局一个, 或者两者兼有.
从而这里可以进一步细化任务分配策略 (push / pull / job scheduling / ...).

调度策略
- 抢占式式调度 (preemptive): 一个任务随时可被中止, 例如操作系统调度, 进程/线程可以被随时挂起
- 协作式调度 (cooperative): 如果一个任务自己不放手, 或者给出机会, 则可以一直执行下去

一些实现的协程, 如果没有遇到IO调度点, 可以永远霸占执行, 因此一些死循环会导致无法调度.
Goroutine 是部分抢占式的, safe-point才可被抢占, 还是可以做到单Goroutine拖垮整个程序.

https://go.dev/src/runtime/preempt.go

抢占式的调度需要语言层面的支持, 如虚拟机指令执行层面. Erlang的Process, 基于虚拟机指令执行次数调度, 从而实现"真"实时调度.

# libev vs libuv

跨操作系统的事件驱动库

libuv: 非阻塞, 回调方式, 带线程池, 最初为了 Node.js 写的

libev: 阻塞, epoll封装

libevent: libev前任

# GIL

global interpreter lock

CPython字节码执行层面同时只能执行一个, 为了简化GC, 不能充分利用多核, 纯PY代码的计算密集型的任务比较受限 (C扩展代码可以自行实现多线程计算逻辑)

不过也有新的提案去掉GIL, 不过是个困难的工程

https://peps.python.org/pep-0703/

# Python Coroutines

yield

iterator

generator

asyncio

# gevent

gevent = greenlet + libev/libuv

greenlet: C扩展实现的coroutine, 不带调度功能

此外, 标准库patching / 驱动事件调度

好处: 不用改代码, `monkey.patch_all()` save the day, 巨大的实施优势

PY 的模块和普通对象一样, 任人玩弄.
monkey patch, 类似测试时的mock手段, 直接目标模块替换改写相关实现方法, 维护工作很高, 得随时跟进目标模块接口及内在实现逻辑).
以及必须得尽早执行, 否则其他模块引入的是原始的目标模块方法.

ref
- https://blog.gevent.org/2010/02/27/why-gevent/
- https://greenlet.readthedocs.io/en/latest/
- https://eng.lyft.com/what-the-heck-is-gevent-4e87db98a8
- https://www.joelsleppy.com/blog/gunicorn-async-workers-with-gevent/


# tornado

基于asyncio

https://www.tornadoweb.org/en/stable/

# twisted

scrapy框架, 因此爬虫方向才关心

# TODO

事件驱动模式下, 多进程worker是必要的么? 是的, 多核系统场景下 n worker + c courine > 1 worker + n * c coroutine

docker / k8s 时代, 多进程管控挪到 pod 层面管控, 框架本身的master管理进程相对鸡肋了


# WSGI

https://www.python.org/dev/peps/pep-3333/

WSGI: (Python) Web Server Gateway Interface / 针对PY语言的web协议

HTTP -> Web Server -> WSGI server (with app code)

ref Servlet

采集场景打满带宽, 提高资源利用率, 外部目标站点的请求耗时波动非常大 (不可控的网路, 目标服务器处理速度, 触发限流等等);
WEB场景, 不涉及外部API调用的情况下, 主要是数据库/缓存读写, IO相对可控, 主要不是抗请求并发 (多起来数据库也受不了了), 再宽的高速堵点车也难受,
主要还是解决单个慢查询不要影响其他的短请求, 类似堵车后有个快速分流的支路.

## WSGI servers (or Python Web Framework ???)

https://www.fullstackpython.com/wsgi-servers.html

NGINX也实现了WSGI协议, 部署主要是为了分离一些静态请求, 和方便运维吧

werkzeug

flask use werkzeug, 主要是开发用, 缺少生产环境的严肃考量, 足够简单, 对于量少的服务也堪用了

uWSGI

uWSGI: 实现了WSGI协议的web服务器 / 类似NGINX
还实现了HTTP协议, 裸跑的时候用的是这个, 自己搞了一套uwsgi协议(注意区别大小写), 不过应该废掉了

gunicorn

Gunicorn is a robust web server that implements process monitoring and automatic restarts. This can be useful when running Uvicorn in a production environment.

https://docs.gunicorn.org/en/latest/design.html

https://github.com/tiangolo/fastapi

# ASGI

https://www.python.org/dev/peps/pep-33333/
https://asgi.readthedocs.io/en/latest/

Uvicorn is an ASGI server based on uvloop

# 结语

Python并发编程是个后补的, 底子不好, 远没有语言内置的来的方便.