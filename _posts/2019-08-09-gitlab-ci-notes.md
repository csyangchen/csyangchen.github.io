---
title: Gitlab CICD 使用备忘
---

最近我们逐步引入gitlab的[cicd](https://docs.gitlab.com/ce/ci/)功能进行如下工作:

- 代码规范检查
- 单元测试
- 仓库自动生成文件的自动提交
- 镜像构建
- 预览环境自动发布工作

这里持续记录实践中遇到的一些问题和总结.

# 依赖缓存

如果一个项目的依赖很大, 如果每次构建都要重新构建依赖, 非常耗时. 如果将依赖缓存下来, 能够极大的缩短构建时间.
另一方面, 为了完全干净的构建, 当依赖发生改变时, 应当重做依赖构建.
所以缓存键值应当和依赖关系的签名发生某种关系, 比如说`requirements.txt / package.json`发生变更的时候.

然而, 目前并不支持缓存键值基于某些文件签名功能, gitlab项目上也有相关的[讨论](https://gitlab.com/gitlab-org/gitlab-foss/issues/35862).
在此类功能尚未发布前, 之前实践笨一点的一种做法是, 手动维护缓存键值.

```
cache:
  key: 12cdwqew # sha1sum of requirements.txt
```

缺点也很明显, 很容易忘记改.

另外一种做法, 通过在任务里面判断缓存是否应该清除. 以Python项目为例:

```
pylint:
  variables:
    PIP_CACHE_DIR: .pip-cache-dir
  cache:
    key: $CI_JOB_NAME
    paths:
    - $PIP_CACHE_DIR
  before_script:
  - "[ ! -d $PIP_CACHE_DIR ] && mkdir $PIP_CACHE_DIR"
  - diff requirements.txt $PIP_CACHE_DIR/requirements.txt || (rm -rvf $PIP_CACHE_DIR/* && cp requirements.txt $PIP_CACHE_DIR/requirements.txt)
  - ...
```

其他语言项目的确定性缓存依赖, 也可以通过类似的思路来解决.

需要注意一点的是, [不支持项目以外的缓存目录](https://gitlab.com/gitlab-org/gitlab-foss/issues/4431),
因此默认的在$HOME下面的缓存目录通常不能生效, 需要手动指定修改, 在本地项目目录下面找一个来解决, 需要注意避开项目本身的文件目录.

不论缓存目录是否变化, 都会重新上传, 在依赖非常大时, 很容易卡住.
通过指定缓存策略来解决:

```
stages:
- prepare
- test

variables:
  PIP_CACHE_DIR: .pip-cache-dir

build-pip-cache:
  stage: prepare
  image: python:3.7
  cache:
    key: $PIP_CACHE_DIR
    paths:
    - $PIP_CACHE_DIR
    policy: push
  only:
    # 只有在文件变更的时候才会触发改任务执行
    changes:
    - requirements.txt
  script:
  - pip -q install -r requirements.txt

pylint:
  stage: test
  image: python:3.7
  cache:
    key: $PIP_CACHE_DIR
    paths:
    - $PIP_CACHE_DIR
    policy: pull # 只拉取不会上传
  script:
  - pip -q install -r requirements.txt
```

# only:changes

注意到上面的例子用到了only:changes配置, 但是实际上并不好用:

- 在开新分支的时候, only:changes是不生效的, 还是会执行的, 对于我们基于功能分支MR的快速合并开发模式, 很多时候并不能节省CI时间.
- 没有办法手动触发重跑, 因为如果CI认为是跳过的任务, 那么在PIPELINE里面改任务都不会体现出来.

# 增量计算

对于大项目, 每次小的提交触发全量检查, 有些不太必要.

但是基于 git diff 的办法, 有不知道前次构建是否成功.

简单的做法, 假设每次MR目标都是master, 且master一定是正确的, 那么是每次都和master做diff即可.

另外一种想法: 由于缓存一定是任务执行成功才上传的, 我们可以利用这个特性来搞事情. 在缓存目录里面记录上次成功提交的文件digest, 然后diff出来此次变更.

# 镜像相关

最简单的CI中构建并上传镜像到项目registry的任务.

```
build:
  stage: build
  image: docker:18.09-dind
  services:
  - name: docker:18.09-dind
    alias: docker
  variables:
    DOCKER_DRIVER: overlay2
    DOCKER_HOST: tcp://docker:2375
    TAG: latest
  before_script:
  - echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USER" --password-stdin $CI_REGISTRY
  script:
  - docker build --tag $CI_REGISTRY_IMAGE:$TAG
  - docker push $CI_REGISTRY_IMAGE:$TAG
```

问题: 需要用个人的KEY生成并配置一个环境变量. 并没有很好的默认整合gitlab仓库的办法.

## image:pull policy

CI里面需要做单元测试, 自然就需要外部依赖的service.

默认全局配置的拉取策略是 if-not-present.
它的问题在于只认tag, 如果上游发生了变更, 即便是latest tag, 都不会触发重新拉取.
[参考](https://gitlab.com/gitlab-org/gitlab-foss/issues/44594).

我们很多service是基于项目代码构建的, 如测试数据库.
所以为了每次触发拉取新的镜像, 每次变更都要通过手动改tag的方式来触发重新拉取.
即便将该TAG做成一个全局变量, 由于全局变量并不能基于项目文件自动生成, 所以还是不够方便.
以及引发了另外一个问题, 会在测试过程中生成很多临时的垃圾镜像, 又没有很好的办法一键清理掉.

# 变量转义问题

多行变量问题.
命令行传入的OK, 但是手工设置的CICD变量就不行了.
怀疑variables加载的时候被转移掉了.

这个暂时没有好办法


# services

单元测试依赖外部数据库如MySQL等, 需要注入数据库.

本地可以通过挂在到`/docker-entrypoint-initdb.d`的方式来执行, 但是gitlab ci service不支持挂载.
只能在任务中先安装一个mysql-client, 然后手动导入测试数据.

service 启动失败不会导致任务失败.

也缺少确保service已经完全启动的机制. 如果服务启动较慢容易导致任务失败.

https://gitlab.com/gitlab-org/gitlab-runner/issues/4506

# submodule

https://docs.gitlab.com/ee/ci/git_submodules.html

gitlab 子模块需要写相对路径. 在初始化的时候需要注意.

有artifact会导致存留的问题, 从而有子模块的项目重新跑时候会报directory not empty错误.
暂时通过手动初始化子模块的方式绕过

```
before_script:
- rm -rf commonproto/
- git submodule sync
- git submodule update --init
```

https://gitlab.com/gitlab-org/gitlab-runner/issues/4672

# include

涉及的项目一多, 我们就需要抽离任务模板, 做到复用, 并可以跨项目引入.

单个文件内的复用可以利用YML的anchor特性, 多文件的依赖需要使用 include/extends

利用"."开头任务不会被执行的特性, 我们可以构造"抽象任务"以供继承:

```
# file 1
.build:
  ...

# file 2
include:
  files: path/to/file/1

build:
  extends: .build
```

也可以继承多个任务, 所以各种代码逻辑, 依赖/重载/混入/...都可以在CI的YML配置中表达出来了.
维护起来的复杂度, 并不简单.

另外跨项目引入要注意到权限问题, 它是基于任务触发用户的权限来做的. 因此你能够跑的任务, 别人如果没有涉及项目的权限, 就会触发失败.
但这个问题有时候并不会很明显, 因为任务依赖镜像会有缓存, 所以可能刚好没有权限的用户可以访问到他没有权限项目的镜像.
因此我们后面逐步转成了基于include来做CI模板.

# 任务依赖

stages 还是尤其局限性, 同一个stage的任务不能触发依赖顺序.

新的版本学习circle, 引入了DAG的功能, 从而加速构建.

# pages

基于特定的artifact可以生成pages, 并直接访问. 我们一般把测试报告, 或者基于代码生成的文档丢进去.

问题: artifact有失效时间, 所以貌似master分支很久没有构建, pages内容就不见了. 这个可以通过每天例行构建来解决.

遇到的问题, 构建的pages貌似并不是独立的, 如果一个分支构建跳过了pages, 那么主干的分支pages也会不见了. 由于我们基于pages生成各种文档, 因此一旦不可用就很麻烦.

对应ISSUE和解决办法:

- <https://gitlab.com/gitlab-org/gitlab/issues/16208>
- <https://stackoverflow.com/questions/55596789/deploying-gitlab-pages-for-different-branches/58915486#58915486>

本质使用cache来存每个分支构建内容, 不过有个潜在问题是如果分支一多, pages cache会越来越大?

# gitlab runner internals

TODO docker based, like Docker build

# 总结

gitlab ci 配置起来不算复杂, 认真看一下[配置文档](https://docs.gitlab.com/ee/ci/yaml/)就能上手.

但是实践起来会踩到各种问题, 而且由于每次PIPELINE其实执行挺久的, 所以每次调试调整都很浪费时间.
最好能够本地先搭一个gitlab来快速调试构建.

推广中要逐步收紧规则, 先养成大家的绿灯意识, 即CI一定要过, 从而项目逐步规范起来.

成熟项目的CI配置, 其实也挺多的, [参考](https://gitlab.com/gitlab-org/gitlab-runner/blob/master/.gitlab-ci.yml).
看上去都头大, 其本质应当时开发迭代过程中不断反思调整, 并把流程规范通过CI配置的方式固化下来.

对于普通开发同学来说, 引入了CI也会遇到各种"我本地能跑通", 上了CI跑不过的问题, 这个其实是个好事, 说明项目本身的一些依赖关系还是没有表达清晰.
督促大家往可重现的开发测试构建的方向去发展, 以及推动容器化的发布.

已经在用gitlab做代码仓库的公司项目,
可以通过gitlab本身的ci功能已经足够用, 每次gitlab版本更新, 功能迭代也足够及时, 解决痛点,
可以逐步将开发/测试/构建/发布各环节流程规范化,
不用再劳什子去找另外的cicd工具.
