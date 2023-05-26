---
title: Python并发网络编程
---

# multiprocessing

缺点: 系统调度开销太大

# multithreading

缺点: 系统调度开销太大 / 风险不隔离 / 一处逻辑挂了整个程序重启, 影响其他在途计算

需要用户态的轻量的多路任务调度机制

## Python GIL

https://docs.python.org/3/glossary.html#term-global-interpreter-lock

同时只能一个线程计算, 不能充分利用多核, 对于计算密集型的任务比较受限

# coroutine / 协程 / 蝇程 / 用户态进程

大部分任务阻塞在IO上 (网络/文件/...) IO阻塞点是天然的切换任务点, AIO事件通知触发任务切换逻辑

实现方式, 可以是语言层面的多线程worker, 去不断获取/放回任务计算队列

例子: Golang的goroutine / Erlang的process模型 / Actor

# generator && iterator

coroutine
generator vs coroutine
iterator / generator / yield / yield from
coroutine yield =

# gevent & greenlet

pior: eventlet

http://www.gevent.org/

`from gevent import monkey; monkey.patch_all()`

https://www.joelsleppy.com/blog/gunicorn-async-workers-with-gevent/

## 
tornado / twisted / ...

# asyncio / async && await

TODO

# WSGI

https://www.python.org/dev/peps/pep-3333/

WSGI: (Python) Web Server Gateway Interface / 针对PY语言的web协议

HTTP -> Web Server -> WSGI server (with app code)

uWSGI: 实现了WSGI协议的web服务器 / 类似NGINX
还实现了HTTP协议, 裸跑的时候用的是这个, 自己搞了一套uwsgi协议(注意区别大小写), 不过应该废掉了

NGINX也实现了WSGI协议, 部署主要是为了分离一些静态请求, 和方便运维吧

https://www.fullstackpython.com/wsgi-servers.html

## WSGI Framework

uWSGI

Gunicorn is a robust web server that implements process monitoring and automatic restarts. This can be useful when running Uvicorn in a production environment.

https://docs.gunicorn.org/en/latest/design.html

wsgiref
werkzeug.run_simple
flask use werkzeug

主要是开发用, 缺少生产环境的严肃考量

https://www.fullstackpython.com/wsgi-servers.html

https://github.com/tiangolo/fastapi
fastapi / openAPI / frontend

# ASGI

https://www.python.org/dev/peps/pep-33333/
https://asgi.readthedocs.io/en/latest/

## ASGI Framework

Uvicorn is an ASGI server based on uvloop
