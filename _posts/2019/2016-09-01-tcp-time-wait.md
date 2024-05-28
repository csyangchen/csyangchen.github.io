---
title: TIME_WAIT 排查
---

最近在`ss -s`看服务器状态时, 发现TIME_WAIT状态连接数过高, 于是着手解决.

我们的系统:

    (client <-> ) ELB <-> nginx (on multiple host) <-> upstream service

整个链路下来, 每一环都应该是HTTP长连接加连接池解决问题. 不应有频繁的TCP连接建立/销毁.

### TCP TIME_WAIT

TCP连接, 主动关闭方会处于较长的TIME_WAIT状态, 以确保数据传输完毕, 时间可长达2 * MSL, 即就是一个数据包在网络中往返一次的最长时间.

其目的是避免连接串用导致无法区分新旧连接.

过多的TIME_WAIT意味着TCP连接频繁销毁. 另外每个处于TIME_WAIT状态连接仍然占用着端口, 有耗尽系统可用端口的风险.

在系统设计时, 一般不应该由服务器主动关闭连接, 而应由客户端主动关闭, 以避免TIME_WAIT堆积.

### sysctl 相关参数

`net.ipv4.tcp_fin_timeout` ~~MSL时间, 默认60s~~ 这个其实是处于FIN_WAIT2状态的超时时间. Linux系统是写死在Kernel里的(=2*MSL):

    `#define TCP_TIMEWAIT_LEN (60*HZ)`

`net.ipv4.ip_local_port_range` 本地端口范围, 调大一些可以避免端口耗尽的风险.

复用处于TIME_WAIT状态的socket:

- `net.ipv4.tcp_tw_reuse` 复用主动连接, 对于被动接受连接的服务来说无用
- `net.ipv4.tcp_tw_recycle` 可以复用主动和被动连接, 但是对于NAT后面的客户端时会有问题

这两个参数的机制和使用注意, 这里不再展开.
启用了这两个参数, 可以极大减少了TIME_WAIT数目, 但是没有从更本上解决连接创建/销毁过于频繁问题.

### nginx <-> upstream service 环节

因为nginx连接nhttp upstream默认是`HTTP/1.0`, 需要加上如下配置, 强制使用`HTTP/1.1`以使HTTP长连接特性生效.

    upstream service {
        ...
        keepalive N; # 当然这个参数也是要开启的, 以确保nginx和upstream间的连接复用
    }
    ...

    location ... {
        proxy_pass http://service;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

### ELB <-> nginx 环节

nginx的`keepalive_requests`参数限制了一个HTTP长连接内最多可以完成请求数, 默认是100.
当每连接在完成了`keepalive_requests`个请求后, 就被nginx主动断开, 从而导致了TIME_WAIT堆积.

这不合理, 理想状态下应该无论处理了多少个请求, 一直复用连接不断开.
由于 `keepalive_requests`参数不支持 unlimited 的配置, 故只能设成一个较大的值以减少主动断开频率.

### Reference

nginx配置

- <https://www.nginx.com/blog/tuning-nginx/>
- <http://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive>
- <http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_http_version>

杂

- <http://stackoverflow.com/questions/8893888/dropping-of-connections-with-tcp-tw-recycle>
- <https://vincent.bernat.im/en/blog/2014-tcp-time-wait-state-linux.html>
- <http://serverfault.com/questions/425065/nginx-keepalive-requests-what-value-to-use-for-unlimited>

火丁TCP系列

- <http://huoding.com/2012/01/19/142>
- <http://huoding.com/2013/12/31/316>
- <http://huoding.com/2014/11/06/383>
- <http://huoding.com/2016/01/19/488>
- <http://huoding.com/2016/09/05/542>
