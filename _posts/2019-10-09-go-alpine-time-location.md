---
title: go程序alpine容器运行时区报错问题一则
---

# 背景

Clickhouse由于业务需要设置了时区为Asia/Shanghai, 正常go程序能够访问, 容器内的程序不能正常连接, 报错信息为:

    panic: could not load time location: unknown time zone Asia/Shanghai

一通测试下来发现: golang:1.13-alpine里面正常, 非alpine的也正常, 唯独alpine里面执行会报错.

# 原因

定位报错来源于`time.LoadLocation`方法, 实现中涉及到指定时区的场景, 需要从以下外部时区文件查询:

    var zoneSources = []string{
        "/usr/share/zoneinfo/",
        "/usr/share/lib/zoneinfo/",
        "/usr/lib/locale/TZ/",
        runtime.GOROOT() + "/lib/time/zoneinfo.zip",
    }

alpine 镜像为了优化体积, 没有对应路径文件, 因此报错. 
golang:1.13-alpine 之所以正常, 是因为会利用到最后一个go自带的时区文件.

解决办法: 拷贝文件, 并通过`ZONEINFO`环境变量来指定拷贝路径.

例子:

    $ cat tz.go
    package main
    
    import (
        "fmt"
        "time"
    )
    
    func main() {
        _, err := time.LoadLocation("Asia/Shanghai")
        fmt.Println(err)    
    }
    
    $ cat Dockerfile
    FROM golang:1.13-alpine
    ADD tz.go .
    RUN go build -o /opt/tz tz.go
    RUN /opt/tz
    
    FROM alpine
    COPY --from=0 /opt/tz /opt/tz
    COPY --from=0 /usr/local/go/lib/time/zoneinfo.zip /opt/zoneinfo.zip
    RUN /opt/tz
    ENV ZONEINFO /opt/zoneinfo.zip
    RUN /opt/tz

    $ docker build .
    ...
    Step 8/10 : RUN /opt/tz
     ---> Running in af068d9669ab
    unknown time zone Asia/Shanghai
    Removing intermediate container af068d9669ab
     ---> 5b52eef0003a
    Step 9/10 : ENV ZONEINFO /opt/zoneinfo.zip
     ---> Running in 5f19f47a3eba
    Removing intermediate container 5f19f47a3eba
     ---> 6488c170777c
    Step 10/10 : RUN /opt/tz
     ---> Running in 8af9127b83a9
    <nil>

alpine体积虽小, 用起来坑多, 一个一个踩.

# Reference

- <https://github.com/yandex/ClickHouse/issues/495>
