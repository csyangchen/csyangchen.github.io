---
title: 用 nginx upstream 实现在线服务更新
---

在部署web服务时, 一般单独部署一台ba机器, 上面部署一个nginx反向代理后端的服务程序, 用来做负载均衡.

    upstream backend {
        server backend1.example.com       weight=5;
        server backend2.example.com:8080;
        server backend3.example.com:8080 down;

        server backup.example.com:8080   backup;
    }

在集群部署环境下, 部分后端服务重启时, 可以通过对upstream的server标记为down保证可用.
在灰度更新时, 可以通过调整weight来切流量.

即便在单服务器部署场景, 也需要通过部署nginx, 通过upstream来切给不同的服务.

    upstream backend_a {
        ...
    }

    upstream backend_b {
        ...
    }

    server {
        server_name a;
        location / {
            proxy_pass http://backend_a;
        }
        ...
    }

    server {
        server_name b;
        location / {
            proxy_pass http://backend_b;
        }
        ...
    }

说一下我们现在一个线上服务的情况:
为了优化全球服务访问速度, 每个AWS可用区部署了一套相同的服务.
就近解析服务域名endpoint.example.com.
另外为了方便测试, 每个可用区服务也单独配置的专属域名.
由于请求压力比较小, 每个AWS可用区只使用了一台服务器, nginx和服务部署在一台机器. 配置如下:

    upstream backend {
        server localhost:8080;
        ...
    }

    server {
        server_name endpoint-region-1.example.com endpoint.example.com;
        location /service {
            proxy_pass http://backend;
            ...
        }
    }

那么问题来了, 我在重启一个可用区的服务过程中, 如何保证服务可用?

- 同一个服务起两个, 然后通过调整upstream切换? 太麻烦, 还要解决新旧服务目录切换问题, 另外服务有时要求是单例运行
- 切DNS? 延迟较高
- 307切走请求到另外一个可用区的专属域名? 还是要改nginx配置, 另外有些客户端不支持跟踪重定向

最终解决思路是这样的, 当一个可用区服务重启时, 其他一个可用区的服务作为备胎接管.

    upstream backend {
        server localhost:8080;
        server endpoint-region-2.example.com backup;
        ...
    }

    server {
        server_name backend endpoint-region-1.example.com endpoint.example.com;
        ...
        location /service {
            proxy_pass http://backend;
            ...
        }
    }

在本地服务(localhost:8080)不可用时, nginx会尝试代理到backend-region-2.example.com,
注意发出的HTTP请求的Host不是backend-region-2.example.com, 而是upstream的名字, 即backend,
所以需要在backend-region-2.example.com机器上配置server_name backend,
以正常处理来自backend-region-1.example.com的代理请求.

这样我们就可以很方便的依次重启每个可用区的服务, 而不用担心服务不可用.
唯一的缺憾就是, 在代理访问另外区域的的服务时, 由于网络延迟, 响应时间会有显著增加.
