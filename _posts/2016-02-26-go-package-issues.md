---
title: Golang package 吐槽
tags: golang
---

Golang package 机制给我的感觉像 Java/C++/Python 杂糅的产物.
也许是我习惯了以单个文件, 或者说类为基本模块的代码组织方式,
对于Golang, 还没有找到一个正确的"姿势"去组织代码吧.

下面就开启"吐槽"模式.

# package名难取, 容易和变量名"撞车"

来看下面这个简单的例子

	// config/Config.go
	package config

	type Config map[string]interface{}

	func Get(path string) interface{} {
		 return "package method Get"
	}

	func (self *Config) Get(path string) interface{} {
		return "member method Get"
	}

    // main.go
	import path/to/config

	func main() {
		fmt.Println(config.Get("path")) // output: package method Get
		config := config.Config{} // NOTE: this is EVIL !!!
		fmt.Println(config.Get("path")) // output: member method Get
		// from this point on, config THE PACKAGE is shadowed
		// we are looking at config THE VARIABLE !!!
	}

所以一方面, package 在取名的时候, 需要想办法避开那些很可能作为变量名的名称.

这个问题在标准库里面就体现出来了:
如`bufio`不叫`buff`, 为了绕开这个太常见的变量名;
`hash`/`sql`命名就很不幸, 在使用的时候需要千万绕开.

## Java怎么做的?

Java 里面, 代码是严格按照类来组织的. 不同于 Golang 一次将整个 package 引入, Java 是对每个类单独引入.
按照 Java 习惯, 类名首字母大写, 变量名首字母小写, 故而从名字上就能很好地区分类调用和对象调用.
就算你"不走寻常路", 要变量名和包名撞车, 那也不会有什么危险, 因为都一定是调用同一个静态方法.

	package path.to.config.Config;

	class Config {
		public static String Get(String path) {
			return "package method Get";
		}
	}

	import path.to.config.Config;

	...
	Config config = new Config();
	Config.Get("path");
	config.Get("path");
	Config Config = new Config(); // confusing but can compile
	Config.Get("path");
	...

## 如何避免

也许Golang编译的时候对这种撞车检查, 拒绝通过.

或者参考C++的namespace语法, 将 package 方法调用和对象方法调用分开:

	auto config = new config::Config();
	config.Get("path"); // member method
	config::Get("path"); // namespace function

回到现实, 以上两点只是妄想, 语法规则一旦订立, 就没法再改了.
连[govet](https://github.com/golang/lint/issues/27)都拒绝侦测这种情况, 所以还是得靠自己注意.

## 如何实现"静态方法"

可以通过构造一个"占位"的类型来实现类似Java的纯静态类:

    // binary.go
    type littleEndian struct{}
    var LittleEndian littleEndian

    func (littleEndian) Uint16(b []byte) uint16 { ... }

    ...
    // caller
    binary.LittleEndian.Uint16(b)

这种写法适用于实现非常类似, 没必要拆分到不同package的场景.

# 要我短? 臣妾做不到

Golang 鼓励命名简短, 但是简短命名带来的时更高的命名冲突几率. 很多时候不得不退而求其次.

## package 重名

    ks/
        writer/
            config.go
            writer.go
        reader/
            config.go
            reader.go
        config.go
    rq/
        writer/
            ...

    // client code
    import path/to/ks/writer
    // import path/to/rq/writer // collide
    import rqwriter path/to/rq/writer // import alias
    ...

同时 import `ks.writer` 和 `rq.writer` 的时候, 就会 package 名冲突.
只能求助 import alias, 实在不太优雅.
Java 另外支持全量路径引入, 也算是一个办法, 而Golang则不支持 (这点估计和C++学的, 但人C++可以`a::b::c`啊).

YY一下, 要是支持使用相对/绝对 package 路径的引用, 那也不错:

    path/to/ks/writer.New()
    // or
    ks/writer.New()

为了避免自己写的 package 被 import alias (打脸么这不是), 实际点的做法:

- `ks.writer` 重命名为 `ks.kswriter`, 或者 `ksw` ?
- hack一点的做法, 在`ks` package 下加路由:

    // ks/ks.go
    import path/to/ks/writer

    type writer struct {}
    var Writer writer // Anchor Variable

    func (Writer) New() *Writer { return writer.New() }
    ...

    // client code
    w := ks.Writer.New()

- 将`ks.writer`, `ks.reader`放到`ks`下, 看上去舒服一些. 不过这这就又带来了下面这个问题

## 同一个 package 下的命名困惑

如果为了package 名简短, 那么对象名, package 的方法名, 就简短不了:

    ks/
        common_config.go // type CommonConfig
        writer_config.go // type WriterConfig
        reader_config.go // type ReaderConfig
        writer.go
        reader.go

而且创建对象的方法名也需要修改

    writer.New() -> ks.NewWriter()

所以说, 取简短有力的名太难.

# side effect import 带来膨胀

Golang package 是最基本的 import 单位, 因此会导致不必要的额外依赖. 还是上面的例子:

    ks/
        writer.go // no import
        reader.go // import other N packages

    // client code
    import /path/to/ks
    ...
    w := ks.NewWriter()

尽管没有用到`reader.go`, 但还是得默默承担reader引入的package所带来的执行文件的膨胀.

也许这就是静态链接所带来的代价? 但人家C++就可以做到没用的代码就不编译.

所以如何组织好 package 的结构, 减少不必要的依赖引入, 也是个比较麻烦的事情.

# 静态编译 vs 依赖注入 (DI)

静态编译好处是非常明显的, 但有时也导致了一些不灵活.
比如说在做依赖注入的时候, 就比较难办. 没法在不改代码的情况下替换一部分组件.
最好的办法, 是在入口文件的地方做依赖注入.

    import (
        "path/to/ip" // 实现IP库的接口定义
        _ "path/to/geoip2" // 一种实现
        // _ "path/to/ip17mon" // 另一种实现
    )

    func main() {
        ...
        ip.New(config)
    }

一种解决办法, 是在编译的时候指定要包含的package, 通过 `go generate` 打进去.

# main package 粘性问题

main package 意味着什么? *代码黑洞*:

- 只可以它复用其他库, 而不能被其他库复用;
- 太容易通过全局变量交互, 导致代码越来越"黏";
- 没法导出多个可执行程序, 除非在程序内部做方法路由

所以项目到了一定规模, 必然要对 main package 作拆分.

Java里面, 每个类都可以定义`public void static main()`方法, 从而作为入口函数.
Golang 类似特性的缺失, 在做模块测试的时候就会比较麻烦.

# 可见性问题

Golang 用大写开头决定可见性, 只有public/private语义.
和C++/Java相比, 缺少了protected概念, 这在绝大部分情况下是OK的.

但是当我们一个内部实现越来越复杂, 需要拆分成几个内部模块.
由于没有机制保护其可见性, 就会被外部 package 调用, 对重构造成不必要的麻烦.

为了解决这个问题, Golang 1.4 引入了 internal package.
internal是protected属性, 仅对当前及更深层级的目录可见.

# 依赖问题

`go get`是非常完美的工具, *如果*:

- 网络永远联通
- 每个 repo 网站永远不掉链子
- 每个 package 永远都只有一个版本

于是就有了 [gopkg.in](http://labix.org/gopkg.in), 提供API兼容的版本管理.

此外, 有类似[govendor](https://github.com/kardianos/govendor)等第三方依赖管理程序,
将依赖库的精确版本(commit hash)记录下来.
从而可以通过依赖库的 commit hash 校验来做到确保 "可重现" 的构建.

此外, 为了解决第三方依赖不可用的危险 (比如github挂了, 偷偷改commit历史啥的),
建议将依赖的代码全部拷贝到`vendor`目录.

但是还存在一个依赖冲突的问题, 比如:

    B depends on A.v1, ...
    C depends on A.v2, ...
    C depends on B

如何构建C?

为了避免了传递性依赖所带来的潜在依赖冲突,
只能要求每个项目"自举", 也就是每个项目, 统统没有外部依赖, 自然也就木有冲突了.

Golang 1.6 之后正式采用了 vendor 的方式来自举. 即把所有的依赖拷贝到 package 内部, :

    C/
        vendor/
            /the/long/path/to/A.v1
            /the/long/path/to/B/
                vendor/
                    /the/long/path/to/A.v2
                    ...
            ...

当然这带来的弊端就是依赖代码的膨胀.
试想一下, 如果项目所依赖N个库都用vendor方法依赖了一个通用库, 那么这个通用库在vendor目录下就出现了N次!
因此, 会随着vendor使用的逐步采用, 指数膨胀下去.

govendor 的思路是将相同的 package 全部拍平.

此外, 如果被重复依赖的库不是静态的纯函数调用, 而是带状态的服务, 那么如何决断, 也是悬而未决的事情...

# Reference

- [Organizing Go code](http://blog.golang.org/organizing-go-code)
- [Go 1.4 “Internal” Packages](https://docs.google.com/document/d/1e8kOo3r51b2BWtTs_1uADIA5djfXhPT36s6eHVRIvaU)
- [Go 1.5 Vendor Experiment](https://docs.google.com/document/d/1Bz5-UB7g2uPBdOx-rw5t9MxJwkfpx90cqG9AFL0JAYo)
- [The New Go 1.5 Vendor Handling](http://engineeredweb.com/blog/2015/Go-1.5-vendor-handling/)
- [Understanding and using the vendor folder](https://blog.gopheracademy.com/advent-2015/vendor-folder/)