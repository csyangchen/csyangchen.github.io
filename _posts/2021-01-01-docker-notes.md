---
title: docker使用问题记录
---

我们逐步推动用docker image的方式管理程序. 本地用docker-compose的方式做本地开发和CI测试流程.
线上部分服务图方便直接机器上docker run跑, 也逐步往k8s部署的方式迁移.

这里记录一些使用中遇到问题.

---
退出信号问题

问题背景:
机器上一些docker run的程序通过[supervisorctl](http://supervisord.org/)来管理, 但是会发现supervisor里面停掉的程序实际上还在跑;
此外docker里面如果有跑子进程的情况, 会有退出信号广播问题.

程序退出流程一般分软退出信号, 等待超时后直接`SIGKILL/9`. `docker stop`默认给的是`SIGTERM/15`.
一般我们程序上统一用`SIGINT/2`代表退出信号.
可以在Dockerfile里面指定`STOPSIGNAL`或者启动的时候指定`docker run --stop-signal SIGINT`来解决.
我们用[dummy-init](https://github.com/Yelp/dumb-init)来解决问题, 以及通过信号改写`--rewrite 15:2`来达到一致的退出处理逻辑.

---
dockerd root权限问题

不留心默认root跑dockerd, 可以轻松宿主机提权. 非常大的安全风险.

`docker run --rm -ti -v /:/host alpine`

---
docker-compose build / docker build 不能复用缓存

<https://github.com/docker/compose/issues/7905>

办法: 避免docker-compose build, 先docker build再重启对应服务

---
log配置

<https://docs.docker.com/config/containers/logging/configure/>

默认的`json-file`性能不好, 且没有配置日志轮转的, 很容易日志爆磁盘.
尽量用`--log-driver local`, 默认会配置日志轮转.
对于有管控的服务, 用`--log-driver none`, 避免STDOUT/STDERR被重复写日志.

---
--network host 的影响

为了随机监听端口做服务注册/监控抓取, 或者偷懒要直接访问宿主机/localhost上服务.
这种网络模式下直接利用宿主机器网络栈. 一个容器重启时候就会触发宿主机器网络栈调整.
我们很多调度定时任务也是docker run起来的, 频繁执行会导致宿主机器网络不可用.

---
总而言之, docker run不是一个严肃的生产环境部署服务的方式, 局限于本地开发测试, 生产环境还是避免.