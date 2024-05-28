---
title: Python版本更新历程
---

目前涉及项目从PY2, PY3.5到3.10一路升上来. 记录备忘下各版本有用到的新特性.

# PY2

PY2TO3是个非常痛苦的过程, 目前业务上还有PY2的后台服务, 不做大的新功能功能开发的话, 没有动力去改.
此外, 系统服务永远不会默认PY3, 平常一些基础运维工具, 如ansible, supervisor等, 永远停留在了PY27.
不过换个角度想, 也是个好事情, PY2的相关依赖永远不会乱升级版本导致各种问题了, 原则上非必要不升级.

> if not broken don't fix it.

# [3.5](https://docs.python.org/3/whatsnew/3.5.html)

是非常重要的版本, 正式引入了[类型注解](https://peps.python.org/pep-0484/) (type hint),
及[协程机制](https://peps.python.org/pep-0492/) (coroutine / async / await),
此后每个版本, 都有非常大篇幅持续完善这两个方面.

当时业务很多历史PY2服务迁移目标确定为3.5, 方便顺便加上最基本的类型注解.
不过类型注解主要是文档作用, 没有执行期间的检查机制, 主要靠各大IDE集成提示警告. 需要调研下相关类型检查的工具.

# [3.6](https://docs.python.org/3/whatsnew/3.6.html)

字典结构实现优化, 除了性能提升, 业务上非常重要的影响是, 可以认为字典键值是保证插入顺序的, 业务逻辑可以直接废掉以往需要用`collections.OrderedDict`的处理步骤.

增加了f-str, 字符串格式化的语法优化逐步减少了打日志需要敲击键盘次数:

```
x, y = 1, .123
"x={x} y={y:.2}".format(x=x, y=y)
# after PY36
f"x={x} y={y:.2}"
# after PY38
f"{x=} {y=:.2}"
```

# [3.7](https://docs.python.org/3/whatsnew/3.7.html)

没有什么大的特性, 曾经用过`time.time_ns`做唯一ID生成.
不用`time.monotonic`原因是其结果和时间戳没有什么关系, 不好后续解析处理.

PY字典保障写入顺序遍历, 从语言层面得到了保障.

新增`@dataclass`方便构造类似POJO的数据对象, 可以用来替代使用namedtuple的场景.
不过目前不涉及这块儿数据结构的使用, 交互数据对象结构, 从方便角度统一字典, 需要考虑内存开销的时候用元组即可.
用PY就图个方便, 没必要OO的方式去做.

新增的几个环境变量/命令行参数比较有意思:

- `PYTHONPROFILEIMPORTTIME / -X importtime` 用来开脚本启动到底哪些模块耗时比较久, 用来方便抓出哪些模块在加载阶段做很重的逻辑
- `PYTHONUTF8=1 / -X utf8=0` 强制默认编码为UTF8, windows环境开发者的福音, 再也不用烦恼 `UnicodeDecodeError: 'gbk' codec can't decode` 的错误
- `PYTHONDEVMODE / -X dev` 开启一些额外的检查, 主要是输出一些额外的警告信息, 严肃的开发者还是需要关注这些警告

# [3.8](https://docs.python.org/3/whatsnew/3.8.html)

几个新特性都非常有用

支持条件语句中创建变量, 感觉从Go抄过来的语法. 虽然变量作用域仍然会逸出if语句, 但至少在形式上明确了变量作用域范围

```
a = get_file()
if f.endswith(".jpeg"):
    handle(a)
# a never used after this line

# PY38
if (a := get_file()).endswith(".jpeg"):
    handle(a)
```

函数签名约束可以明确/约束参数调用形式, 在业务代码里面我们鼓励甚至要求, 降低误传参数的风险, 保留接口作者腾挪的空间

```
def f(a, b, c=3):
    pass

def g(a, /, *, b, c=3):
    pass

# f调用方式太乱
f(1, 2, 3)
f(1, b=2)
f(a=1, b=2)
# g明确了参数调用方式
g(1, b=2)
```

f-str可以直接基于变量名显示, `f"{duration=}` VS `f"duration={duration}"`, 极大减少了输入冗余, 对于我们打kv形式的日志格外方便, 也逼着大家把变量命名写好一些.

# [3.9](https://docs.python.org/3/whatsnew/3.9.html)

业务代码上经常误用`str.lstrip / str.strip`, 测试不充分的情况下很容易漏BUG, 如`filename.rstrip(".jpeg")`, `url.lstrip("www.")`.

新增的`str.removeprefix / str.removesuffix`, 虽然只是`s[len(prefix) :] if s.startswith(prefix) else s`这样一个简单逻辑,
内置实现后速度压测会快2倍多, 对于高频调用的逻辑还是值得的.

类型注解的简化, 能够降低开发写的意愿 `f(x: list[dict[str, int]])` VS `f(x: typing.List[typing.Dict[str, int]])`,
绝大多数情况都是内置数据类型的传递, 可以基本告别`typing`模块依赖.

# [3.10](https://docs.python.org/3/whatsnew/3.10.html)

[匹配语法](https://peps.python.org/pep-0636/)是个非常有用的特性, 它不仅仅是`case ... when`语法糖, 可以做模式匹配编程, 声明式的表达, 个人经验非常适合写业务逻辑, 可以让表达足够简洁有力.
把复杂的业务判断逻辑做精简, 平铺直叙, 不用头疼在现在多层`elif`嵌套里面.

类型注解支持默认的union简化表达 `x: str | bytes` VS `x: typing.Union[str, bytes]`,
不过业务上尽量避免多类型参数/结果, 尽量往静态类型语言上去靠.

`int.bit_count`简化了之前需要`bin(x).count("1")`做位图统计逻辑, 性能上来说没有测到特别显著的提升.

`zip(..., strict=True)` 作为一个后知后觉的安全检查选项, 确保协走对象数据等长, 不过默认没有开, 可能是从兼容性的角度考虑.

`@dataclass`支持`__slots__`, 从而优化数据类的性能.
`__slots__`明确约束了对象容许字段, 可以更好的优化内存布局, 加速对象属性访问, 并禁止了未声明字段的动态创建, 相对安全一些.

# [3.11](https://docs.python.org/3/whatsnew/3.11.html)

Guido"退休"后在微软"养老"的[Faster CPython](https://github.com/faster-cpython/ideas/blob/main/FasterCPythonDark.pdf)工作出有硕果,
声称大幅提高了速度.

从发布记录里面看, 主要是通过预加载编译代码提高启动速度; 运行时优化/复用调用栈, inline函数调用, 部分实现了尾递归优化(?), 以及类似JIT的执行机制.
感觉和JVM的优化手段思路一致.

https://github.com/faster-cpython/ideas/issues

# [3.12](https://docs.python.org/3/whatsnew/3.12.html)

爱写comprehension的有福了, [PEP 709](https://peps.python.org/pep-0709/) 将表达式内联, 不创造匿名的函数, 从而优化性能

# PY性能优化

其实每次版本发布都有非常多的性能优化点记录在`#optimizations`章节, 这也是我们跟着版本升级后, 除了新特性外, 直接享受的改善.

拿一个jieba分词测试的结果

```
2.7.18 load_sec=0.77 calc_sec=8.84
3.5.10 load_sec=0.71 calc_sec=8.79
3.6.15 load_sec=0.61 calc_sec=8.53
3.7.15 load_sec=0.59 calc_sec=8.36
3.8.15 load_sec=0.58 calc_sec=8.04
3.9.15 load_sec=0.57 calc_sec=7.98
3.10.8 load_sec=0.51 calc_sec=7.34
3.11.0 load_sec=0.50 calc_sec=6.50
```

PY脚本主要图方便灵活, 或者说的不好听一些, 当作胶水语言.
"正常"的程序, 主要瓶颈一定在于于外部IO交互, 涉及计算密集的一般委派到对应的库实现,
因此针对PY语言本省的性能优化其实大概不一定是个非常重要的事情.

PY使用者角度而言, 日常优化性能的一些手段

- 避免用PY计算, 优先选择C实现, 如
  - [confluent-kafka](https://pypi.org/project/confluent-kafka/) OVER [kafka-python](https://github.com/dpkp/kafka-python), 实测下来前者有非常大的性能优势
  - [rapidfuzz](https://pypi.org/project/rapidfuzz/) C++实现距离计算, 直接吊打任何纯PY实现算法
  - 用numpy/pandas等做数值计算, 以及一些比较大的数据处理过程
  - C for performance, 不过C实现的库DEBUG起来都很难, 很多时候还会遇到各种内存相关, 或者异步交互的问题, 需要审慎衡量得失
- 避免外部交互
  - 避免IO
  - 避免系统调用, 如时间相关等
- 力求懒, 避免不必要的过程, 不必要的计算, 如
  - 程序内部重用/缓存, 如 `functools.lru_cache`
  - 避免无效日志 `logging.debug(do_something)`
  - 避免字符传拼接 `str.append`
  - 避免重复 `handle(d[k]) if d.get(k) else ...`
  - 重排序逻辑, 轻量的计算优先处理, 相当于对于代码条件判定路径做最短编码
  - 面向迭代器编程, 可以减少内存开销和很多不必要的计算
  - ...
- 使用尽可能简单紧凑的数据结构
- 一般来说, 写的愈精简性能自然不会差的, 个别情况下, 实现层面的性能考量和可读性考量是矛盾的, 这时候坚决考虑后者, 或者"诱惑"太大时, 做相应的封装隔离
- 最后最重要的也是最有效的手段, 是从程序要解决的问题, 其目的, 及设计角度出发, 思考最优的策略, 实现层面的一些细节考量其实影响不大
  - "战略对了, 战术小的错误不关紧要; 战略错了, 再有效的战术执行也是徒劳无功"

# PY3版本升级之痛

PY3并不保证版本向前兼容, 基本每次升级, 都有一大堆依赖的各种兼容性问题需要解决, 需要调整依赖项目对新版本做兼容适配.

例如
```
# NOT OK since 3.10
from collections import Mapping
cannot import name 'Mapping' from 'collections'
```

在之前的3.9版本里面[提了一嘴](https://docs.python.org/3/whatsnew/3.9.html#you-should-check-for-deprecationwarning-in-your-code).
并在3.10里面[正式移除](https://docs.python.org/3/whatsnew/3.10.html#removed).
这个其实在PY3.3里面就标记淘汰了, 但是以程序员的尿性, 没人关心`DeprecationWarning`.

同理`pkgutil.ImpImporter`, 3.3版本deprecated了, 3.12里面才正式去掉, 导致了一堆问题. 需要等各个依赖跟上.

因此每次发布, 需要特别关注`#removed`章节, 有责任心的三方库作者需要提前跟进`#deprecated`章节.

一些重要依赖的包, 如pytorch, onnxruntime等, 都是默认不支持相信版本的, 需要等打包显式支持才能用上. 这又拖慢了新版本的纳入节奏.

三方依赖的变更, 又涉及各种恶心的[依赖地狱](https://pip.pypa.io/en/stable/topics/dependency-resolution/)问题, 不展开.

对于我们业务代码维护的启示, DEPRECATION过程其实可以更加决绝一些, 除非有机制能够锁住并禁止新的代码调用DEPRECATED CODE, 否则DEPRECATION只是"防君子不防小人".

依赖管理角度, 为了避免一定要锁到最细粒度, 也要声明所有间接依赖库, 目的一个是避免触发依赖检查回溯, 二是确保每次确定性的构建, 当然最好的情况是自建依赖镜像, 避免三方作者抽疯了.

非必要不要引入太多的依赖, 导致项目的脆弱性. 这点GO就做的不错, 项目没用到的依赖直接就自动删掉了. 目前我没有找到很好的办法确保PY项目最简依赖的办法.


# Reference

- https://github.com/microsoft/onnxruntime/issues/14880
- https://github.com/pypa/pip/issues/11501