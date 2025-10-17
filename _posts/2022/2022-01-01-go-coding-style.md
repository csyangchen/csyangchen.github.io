---
title: 项目代码规范
---

存档用途

# Reference

首先, 请熟读:

- https://golang.org/doc/effective_go.html
- https://github.com/golang/go/wiki/CodeReviewComments
- https://dmitri.shuralyov.com/idiomatic-go
- https://12factor.net/

# 程序设计原则

代码应当逻辑清楚, 并且性能友好

- 逻辑清楚: 代码是给人读的, 平铺秩序, 避免过度的代码切割; 将业务无关繁冗的逻辑抽离出来
- 性能友好: 简单, 思路清晰的代码一定是性能有好的
- 使用固定的既有写法"套路", 从而保证代码阅读时充分的“预信息", 避免理解上的解读负担

# 最小暴露原则

业务代码, 优先使用一个`main package`解决战斗.

如无特别原因, 优先使用`internal package`, 减少暴露范围.

能在一个package里面完成的, 不拆分成多个package.

package内尽量使用私有成员, 避免暴露.

暴露的接口尽量用`interface`返回, 避免暴露具体实现, 方便替换实现和mock测试.

高内聚, 低耦合, 避免不必要的对外暴露. 优先私有方法, 及内部 package.

对外方法尽量多写说明文档.

尽量使用局部方法, 有时候有点冗余也没有问题, 也方便重构和模块间解耦. 尽量避免全局在用目的性又不强的所谓的`util`库.

避免不必要的类方法. 考虑用一个简单的函数来替代.

代码保持精简, "清爽": 业务代码, 不要保留未被调用的方法.

避免使用全局变量, package层面的主动初始化方法签名 `Init(c *Conf) error`, 只允许在`main`方法里面做, 以避免重复初始化.

避免有状态的方法.

## 服务结构约定

单个"简单"服务的目录结构: 一个 `package main` 内完成

    app/
        main.go 入口程序
        conf.go 配置定义文件, 建议单独写, 好处是写配置文件时便于查找配置定义
        README.md 服务/业务的简单介绍等

单个"复杂"服务的目录结构:

    app/
        internal/ 内部库
        app/ 外部lib层面依赖, 如有
        appschema/ 外部代码层面依赖的结构定义等, 如有
        appclient/ 调用该服务的client封装, 尽量使用interface便于替换以及mock测试, 注意不必要的依赖传递
        main.go 服务入口程序
        app.go 一些内部逻辑, 由于是`package main`, 不用太担心对外暴露的问题
        README.md 服务/业务的简单介绍等

注意 appschema/ 目录尽可能简单, 因为别的项目有可能会调用, 尽量不要在里面写逻辑方法, 以避免不必要的关联引入问题.

## 代码规范

确保每次提交都是可构建的, 使用统一的格式化和检查工具, 避免无意义的修改反复污染历史纪录.

import package 顺序: 优先标准库并在一个import block里面按照顺序完成, 其次第三方库. 目的, 确保 import 行是确定的. 建议使用 `goimports` 整理好顺序.

避免 import package alias

package名和目录名称保持一致

条件判断时, 将变量放在坐边, 常量放在右边. 不用担心写成赋值语句, 因为Go本身赋值是不能作为条件判断语句的

        // DONT
        if nil == err {
            ...
        }
        // DO THIS
        if err == nil {
            ...
        }

代码追求简洁, 不要再出现类似这样的代码:

        // DONT
        if a > 0 {
            return true
        }
        return false

        // DO
        return a > 0


避免状态依赖, 避免全局(服务)对象. 如果实在要用的话, 用`g`前缀标注全局变量.

不允许package直接暴露全局对象, 需要的话, 使用package方法封装.

不许主动 panic !!! 例外 `main.go`服务初始化的过程.

避免使用 zero value 传递有效业务数据 !!!

避免指针列表. 除非有特别的理由, 对于列表, 优先用`[]T`, 不要用`[]*T`. 理由:

- 内存局部性考虑
- `[]{nil}` 会序列化为 `{null}` 调用者端需要额外判断

命名规范: golint友好, 避免使用下划线, 统一使用驼峰风格. 变量名统一小写开头.

避免会导致和标准package名冲突的变量名称, 不允许变量名和引入的包名发生冲突.

同一个作用域内, 避免同名变量, 以及 variable shadowing, 以简化理解难度.

不要提前定义变量, 在最迟使用的地方直接赋值.

空字符串判断统一用`!= ""`, 列表判断统一用`len(l) != 0`

        s := ""

        // DONT
        if len(s) != 0 {
            ...
        }

        // DO
        if s != "" {
            ...
        }

        var l []T

        // DONT
        // 无法区分空列表和没有元素的列表
        if l != nil {
            ...
        }

        // DO
        if len(l) != 0 {
            ...
        }

参数类型声明不建议略写

        // DONT
        func Foo(a, b string)

        // DO
        func Foo(a string, b string)

        // DONT
        var a, b string
        // DO
        var a string
        var b string
        // 更加建议的手法
        a, b := "", ""

不用自己定义实现 `sort.Interface` 接口, 优先使用 `sort.Slice` 方法. 更加简洁.

测试文件不要使用额外的`_test`后缀的package名, 因为需要全量引入测试的package路径, 不便于重构.

不许阻塞写 channel


		// DONT
		ch <- msg

		// DO
		select {
		case ch <- msg:
			// OK
		default:
			// error logging, retry logic, etc.


		// 有 ctx 的场景
		select {
		case ch <- msg:
			// OK
		case <-ctx.Done():
			// ctx timeout
		}

schema package 里面避免堆砌业务逻辑

if 语句赋值和判断何时放在一行? 当该变量作用域不超过该scope时, 用同行, 否则换行写.

    if var, err := QueryAd(); err != nil {
        ...
    }

    ad, err = QueryAd()
    if err != nil {
        ...
    }

用不到的变量, 又必须满足一定范式的, 用_标记:

    Query(_ context.Context, ...)


不鼓励使用, 但又一时没法重构掉的方法, 用`DEPRECATED`注释标记, 并禁止增加对于该方法的调用.

# 配置相关

    // 配置定义
    type Conf struct {
        ...
    }

    // 数据验证和默认值填充, 预处理等操作
    func (c *Conf) Validate() error {
        ...
    }

    // 初始化服务套路, 如有依赖通过参数传入
    func (c *Conf) New(...) (Service, error) {
        ...
    }

- 统一使用 `time.Duration` 作为时间相关参数
- 将初始化尽量放在`main.go`里面做, 用依赖注入的方式来做服务/模块初始化
- 配置相关结构体统一以`Conf`后缀命名

配置统一使用YAML格式, **不要另外写YAML标签**. 默认配置文件字段等于`strings.ToLower(FieldName)`. 目的是为了方便全文忽略大小写搜索.

        // DONT
        type Conf struct {
            DbDsn string `yaml:"db_dsn"`
        }

        // DO
        type Conf struct {
            DB string
        }

配置组合的时候, 命名尽量依循依赖配置文件的包名.

        // DONT
        type Conf struct {
            AdfetchConf adfetch.Conf
        }

        // DO
        type Conf struct {
            Adfetch adfetch.Conf
        }

用指针对象表示可选依赖

        // DONT
        type Conf struct {
            Sendlist string
            EnableSendlist bool
        }

        // DO
        type Conf struct {
            Sendlist *string
        }

## 日志输出

使用结构化的日志方式. 尽量避免 Printf-like 的日志输出.

    // DONT
    log.Infof("aid=%d req=%#v", aid, req)

    // DO
    log.WithFields("aid", aid, "req", req).Info()

- warn: 外部输入导致的问题, 如无效请求参数, 如投放计划不存在, 等等
- error: 系统本身的问题, 如数据库/缓存查询失败等

不要混用各种输出, 坚持一种输出方式.

对于测试代码, 统一使用 testing.T 的方法. 不另外使用输出方法:

    // DONT
    func TestLowerCase2Camel(t *testing.T) {
        tc := 1
        fmt.Println(tc)
    }

    // DO
    func TestLowerCase2Camel(t *testing.T) {
        tc := 1
        t.Log(tc)
    }

## 错误处理

工具方法不用自己打日志, 由上层调用者打. 避免输出错误日志同时, 又返回error给上层的情况.

建议返回错误信息时, 添加有用的信息以便于定位问题, 不添加调用的信息, 只传递本层的错误信息.

    // DONT
    func foo(...) error {
        ...
        err := bar()
        if err != nil {
            milog.Error(err)
            return err
        }
    }

    // DONT
    func foo(...) error {
        ...
        err := bar()
        if err != nil {
            return errors.New("bar: " + err.Error())
        }
    }

    // DO
    func foo(...) error {
        ...
        err := bar()
        if err != nil {
            return errors.New("foo: " + err.Error())
        }
    }

优先判断

## SQL相关

数据库设计参考[这里](https://conf.umlife.net/pages/viewpage.action?pageId=46242377).

DDL必须在项目里面记录, 以确保自举, 实现单元测试流程.

SQL命令尽量做到能够直接拷贝出来即可测试

避免字符串拼接SQL语句, 有被注入的风险. 建议直接使用占位符方式查询.

不允许返回NULL, 用合理的zero value标记没有数据.

统一使用小写语句.

避免连表操作.

避免批量查询操作: 不利于缓存命中, 加大了单个查询的时长.

避免冗余语句:

    // DONT
    select itg.ader_url, itg.jump from youmi_ad.integration as itg where itg.ctid = ?
    // DO
    select ader_url, jump from youmi_ad.integration where ctid = ?

不到万不得已的时候, 不使用转义符:

    // DONT
    select `key`, `value`, `id` from ...
    // DO
    select `key`, value, id from ...

凡涉及到外部请求的方法， 默认第一个参数是 context, 用于控制超时, 统计监控, 及链路追踪.

数据库相关查询函数签名:

    // result = nil 表示没找到
    func QueryXXX(ctx context.Context, arg1, arg2, ...) (*Result, error)

    // DEPRECATED
    // 对于数值类型无法判断是否找到时用, 当然最好在设计层面避免 0 值 有有效含义的设计
    func QueryXXX(ctx context.Context, arg1, arg2, ...) (ScalarType, found bool, err error)

# Redis 相关

命令统一使用大写

一般来说，涉及到redis / 数据库相关 错误, 不用调用者再输出 错误日志, 由底层库处理这种问题.
因为这种问题要么是语法错误, 这种应该在开发阶段解决掉, 要么就是超时, 这个在请求错误码里面标记处理即可.
业务层面需要判断是否会影响到正常逻辑的继续, 以决定中断当前处理流程还是继续.

# 性能相关

json 用 `json.NewEncoder(w).Encode(v)` 而不要 `json.Marshal(v)`

避免 `ioutil.ReadAll(r)`, 就算用, 也要确保是有上限的读.

在不影响代码简洁性的前提下, 对于热点路径, 避免 `fmt.Sprintf`.



