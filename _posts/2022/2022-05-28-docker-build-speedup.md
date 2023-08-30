---
title: docker镜像构建加速之路
---

docker是我们目前开发测试部署不可或缺的工具, 常见的Python项目构建文件:

```
FROM python:3.8
ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . .
ENTRYPOINT ["python", "manage.py"]
```

然而随着依赖越来越大, 构建速度越来越慢, 需要想办法加速构建.

# 区分基础镜像和项目镜像

日常业务代码变更频繁, 依赖一般变更频次较低.
此外, 虽然本地构建会利用到分层构建缓存 (DLC / Docker Layered Cache), 但是我们目前基于gitlab-ci的构建方式是docker-in-docker, 并不能利用到该特性,
从而导致每次线上都是从头构建.

因此我们将构建拆成两阶段构建:

1. 基础镜像构建
2. 业务镜像构建

```
> cat base.Dockerfile
FROM python:3.8
ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt

> cat Dockerfile
FROM $BASE_IMAGE
ADD . .
ENTRYPOINT ["python", "manage.py"]
```

本地开发也可以利用基础镜像进行开发测试, 避免本地构建基础镜像的开销.

# 识别有意义的变更

很多时候只是`requirements.txt`里面调整下顺序, 或者写点注释说明, 但是docker构建缓存是基于文件内容变更触发的.

因此, 我们构建的时候, 可以对输入的依赖文件做一个"格式化"过程.

`cat requirements.txt | sed 's/\s*#.*//g' | sort -df | uniq > .requirements.txt`

再进一步, 基础镜像标签基于该逻辑语义生成

`DIGEST=$(cat requirements.txt | sed 's/\s*#.*//g' | sort -df | uniq | sha1sum | cut -c 1-4)`

这样一来, 依赖声明文件随便调整, 只要实质上没有发生变更, 就不会触发重构构建.

# 减少build context

构建基础镜像的过程中, 虽然只是依赖一个`requirements.txt`文件, 但是构建启动依然很慢. 原因是构建时会默认把当前目录内容全部传进去.

一种办法是构建基础镜像时用一个单独的目录制作

```
rm -rf .build-base
mkdir .build-base
cp requirements.txt .build-base/requirements.txt
cp base.Dockerfile .build-base/Dockerfile
docker build .build-base
```

更好的办法是利用[`.dockerignore`](https://docs.docker.com/engine/reference/builder/#dockerignore-file),
忽略不需要传入build context的文件. 加载顺序是优先查找`{dockerfile}.dockerignore`, 默认是用构建目录的`.dockerignore`. 

```
> cat base.Dockerfile.dockerignore
/**
!requirements.txt
# 基础镜像构建 
> docker build -f base.Dockerfile . 
```

同理, 构建业务镜像的时候也一定要编写`.dockerignore` (至少不能少于`.gitignore`),
减少传入的构建文件, 降低构建镜像大小, 杜绝构建过程中的不确定性, 也避免信息泄露.

# 换源加速依赖下载

基础镜像构建最慢, 最不可控的环节在于依赖下载安装, 严重依赖网络情况.
除了网络走代理的办法, 更常规的做法就是换上游源地址, 例如我们国内主要是阿里云上跑, 自然就选用阿里云镜像仓库:

```
pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ -r requirements.txt
```

用`--no-cache-dir`关掉依赖缓存, 以减少构建镜像大小.

不太关心HTTP的潜在风险, 或者在阿里云内网, 可以改成 `--trusted-host mirrors.aliyun.com -i http://mirrors.aliyun.com/pypi/simple/`

类似的, 我们有时候需要更新/安装基础软件, 为了加速也要把源换掉

```
FROM python:3.8
RUN sed -i s/deb.debian.org/mirrors.aliyun.com/g /etc/apt/sources.list \
&& sed -i s/security.debian.org/mirrors.aliyun.com/g /etc/apt/sources.list \
&& apt-get update && apt-get install ...
```

这里多个命令写一行是为了减少镜像构建层级, 常规的构建文件编写操作

# 增量构建/构建缓存

然而当`requirements.txt`膨胀起来后, 每次修改都会导致全量重新下载安装. 有没有办法加速呢?

本地机器上做依赖变更是很简单的, 只会触发新增或者变更依赖的下载安装, 那么类似的想法就是把依赖缓存挂载到构建过程中.

可惜的是, docker构建过程并不支持挂载, 因此这条路行不通.
蠢一点的办法就是通过多阶段构建来实现类似逻辑, 缺点是宿主机器和构建镜像的环境强依赖性.

日常变更依赖构建基础镜像的一种投机的办法是: 如果只是修改或者增加依赖, 那么就从旧的基础镜像二次构建

```
FROM $PREVIOUS_BASE_IMAGE
ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt
```

好处是变更后基础镜像发布只要拉取变更的层即可, 速度快; 缺点是基础镜像层级堆积.

依赖删除不建议如此操作的几个理由:
1. `requirements.txt`里面删除的依赖其实还在, 如果还有旧依赖调用还是可以跑通的, 没有删干净, 重新全量构建后会失败, 导致构建的不确定性
2. 即便主动`pip uninstall`了, 基础镜像大小并没有随之减少   

# BuildKit save the day

随着docker的逐步流行, 构建依赖安装越来越慢的问题逐步放大, 相信各大依赖仓库/三方源是有苦难说, 大家天天`pip install`,
请求压力, 流量成本与日剧增, 很多用爱发电的三方仓库已难以保障服务质量.
连DockerHub都扛不住了, 开始[限流镜像下载](https://docs.docker.com/docker-hub/download-rate-limit/)了.

新的Docker版本, 支持了BuildKit模式, 从而在构建阶段也能用上缓存逻辑, 从而加速构建.

```
# syntax = docker/dockerfile:experimental
FROM python:3.8
ADD requirements.txt requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip,id=base.Dockerfile,sharing=locked \
pip install \
--cache-dir /root/.cache/pip \
-i https://mirrors.aliyun.com/pypi/simple/ \
-r requirements.txt
```

由于还是实验特性, 构建时需要手动设置`DOCKER_BUILDKIT`环境变量开启BuildKit

```
DOCKER_BUILDKIT=1 docker build --progress=plain ...
```

默认的日志输出实在太炫KEN酷DIE, 通过`--progress=plain`设置朴素无华的日志输出格式.

可以随便修改下`requirements.txt`测试重新构建用时, 从日志可以发现, 下载利用了依赖缓存, 修改重新构建瞬时完成.

好消息是, 再也不用担心改依赖后构建慢的问题, 从而懒得修改`requirements.txt`.

坏消息是, gitlab-ci的构建目前仍然没有找到办法支持该特性.

# 精简再精简

不过最有效的办法, 还是从源头上减少不必要的外部依赖, 精简代码.
本着"应删尽删, 非必要不加依赖"的指导原则, 确保整个项目的精简, 是加速构建的最优手段. 

# Reference

- <https://circleci.com/docs/2.0/docker-layer-caching/>
- <https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md>
