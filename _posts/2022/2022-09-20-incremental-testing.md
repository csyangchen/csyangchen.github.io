---
title: 增量测试及依赖提取
---

项目规模上去后, 做一次全量测试/构建耗时也会上来, 动辄一次十几分钟的CI过程会显著降低开发效率.
因此需要做增量测试构建机制, 加速CI. 当然增量测试的大前提在于目标分支的正确性, 所以一般是分支做增量测试, 主干分支定期做全量测试.

传统的C/C++项目做增量构建, 需要手写Makefile规则, 比较繁琐.
Go语言自带了增量构建/测试, 但是由于是基于文件内容变更的缓存, 会漏掉外部依赖, 如环境变量等, 从而导致失效.
本地开发默认 `go test -count=1` 屏蔽掉测试缓存.
语言无关的依赖管理增量构建工具, 如 [Bazel](https://bazel.build/basics) , 对于目前项目规模而言太重, 且需要单独写`BUILD`文件申明依赖关系. 我们希望的是从项目本身自动提取依赖.

我们的项目以Python为主, 不存在增量构建需求, 希望简单的基于项目文件本身做依赖提取及增量测试.

增量测试流程: 构建出依赖DAG, 每次变更, 提取变更节点, 并计算影响的下游节点.

```
def get_effected_files(changed_files):
    # 提取项目依赖关系,
    dag = get_deps()  # {模块: 依赖模块集合}
    # 拍平依赖传导, 不区分直接和间接依赖关系
    flat_dag = flat(dag)
    # 计算反向依赖
    reversed_flag_dag = reverse(flat_dag)
    # 合并变更文件影响的模块
    return set().union(*[reversed_flag_dag[file2mod(file)] for file in changed_files])

def reverse(dag, keep_leaf=True):
    ret = defaultdict(set)
    for k, vs in dag.items():
        if keep_leaf:
            _ = ret[k]  # ensure existence
        for v in vs:
            ret[v].add(k)
    return dict(ret)

def walk(dag, k, seen: set):
    seen.add(k)
    for dep in dag[k]:
        if dep in seen:
            continue
        seen.add(dep)
        walk(dag, dep, seen)


def flat(dag):
    ret = defaultdict(set)
    for mod in dag:
        seen = ret[mod]
        walk(dag, mod, seen)
    return dict(ret)
```

以上流程, 其核心在于提取项目依赖关系.
项目依赖提取出来, 也可以做很多其它事情, 如做一些代码的结构性分析, 无用代码检查, 执行一些项目结构的约束性检查, 计算变更影响的干系人, 需要重新部署的服务, 等等.

具体提取实现方式, 从"懒"的角度, 项目里面执行时已经包含了完整的依赖关系, 不应该再重复两遍别处定义一遍依赖.

# Python静态模块依赖提取办法

最简单的办法就是对于`import`进行分析提取关系, 糙一点就正则直接提取`(import .*)|(from .* import .*)`, 安全一点的办法就利用语法树解析提取:

```
for node in ast.walk(ast.parse(get_file_content(file))):
    is_from = False
    # NOTE 假设代码没有单语句多import
    if isinstance(node, ast.Import):
        mod = str(node.names[0].name)
    elif isinstance(node, ast.ImportFrom):
        is_from = True
        mod = f"{node.module}.{node.names[0].name}"
```

由于Python的import语法比较灵活, 且语言层面上万物皆对象, 不细分库(带__init__的目录)/模块(单个PY文件)/类/函数等概念, 因此提取出来的依赖对象需要做进一步分析.

依赖来源一般分三种: 标准库依赖, 三方库依赖, 项目模块依赖.
对于是否项目模块很好处理, 只要判断模块或者模块前缀对应的文件是否在项目里面即可.
但是对于是否为标准库/或第三方模块就相对比较麻烦,
需要手搓一个标准库列表, 3.10后才有[sys.stdlib_module_names](https://docs.python.org/3/library/sys.html#sys.stdlib_module_names)可用,
或者从[site.getsitepackages()](https://docs.python.org/3/library/site.html#site.getsitepackages)目录列表里面优先去找三方依赖.

至于判定依赖类型, 简单办法, 通过文件校验方式检查

- 库: `os.stat(os.path.join(mod2path(mod), "__init__.py"))`
- 模块: `os.stat(os.path.join(mod2path(mod))`
- 否则: 类/函数/变量/...

或者可以使用动态加载+反射的办法检查是否为模块, 拿标准库举个例子:

```
from os import path  # 模块引入
from datetime import datetime  # 类引入

importlib.import_module("os.path")
>> OK
importlib.import_module("datetime.datetime")
>> ModuleNotFoundError: No module named 'datetime.datetime'; 'datetime' is not a package
```

通过`importlib.import_module`还可以提取到模块的结构信息

```
for name, obj in inspect.getmembers(importlib.import_module(mod)):
    if inspect.isfunction(obj):
        ...
    elif inspect.ismodule(obj):
        ...
    elif inspect.isclass(obj):
        ...
    ...
```

从而利用这些信息, 可以做更细粒度的依赖提取, 及无用依赖检测.

`importlib.import_module`的局限性是对于引入目标提取模块写法有一些额外的要求, 不能有条件引入, 以及side effect的初始化操作.

# 动态依赖提取

静态提取的缺点在于提取的粒度比较有限, 对于函数对模块的依赖提取就比较困难.
此外对于代码import姿势有一定的要求, 以及不能分析动态依赖加载等.

考虑到做profile的时候, 代码的调用链关系其实已经知道了, 因此简单的想法就是通过运行时调用栈动态提取依赖关系并记录下来.


```
import profile
p = profile.Profile()
p.run(...)
for (file, linenum, method), (cc, ns, tt, ct, callers) in p.timings.items():
    for (call_file, call_linenum, call_method) in callers:
        print(f"{file=} {method=} {call_file=} {call_method=}")
```

然而profile只能提取到运行时代码的依赖关系, 对于动态模块加载的骚项目没有办法.
需要拦截动态加载的函数入口 (`__import__` / `importlib.import_module`), 并在运行时提取调用栈关系, 找出模块动态依赖关系:

```
import builtins
from importlib import import_module as builtin_import_module

def my_import(name, **_):
    frame = inspect.getframeinfo(inspect.currentframe().f_back)
    print(f"{frame.filename} import {name}")
    return builtin_import_module(name)

builtins.__import__ = my_import
importlib.import_module = my_import
```

动态提取的缺点在于, 需要一个覆盖率100%的回归流程. 正常的业务代码不太可能做到这一点.

# 外部数据依赖提取

以上说的都是单语言代码内部的依赖提取, 实际情况是很多非代码变更依赖, 如数据库DDL文件变更, 模型文件变更, 等等.
如何提取关系, 从而测试数据或者表定义变更时, 只跑最少的测试来验证正确性呢?

一种办法比较粗糙, 就是外部依赖全部代码化, 如:

```
from config import MYSQL_DB1_DSN  # 数据库DB1的指向变量

@pytest.mark.skipif(not MYSQL_DB1_DSN, "MYSQL_DB1_DSN not set")
def test_xxx():
    ...
```

DB1的变更依赖通过`MYSQL_DB1_DSN`变量依赖抓出来. 当然缺点也很显然, 依赖提取粒度太粗.

其它办法, 同动态依赖提取类似, 通过注入对应的外部文件的读写入口方法, 提取出来所需粒度的依赖关系:

```
# 假设所有外部数据库服务的读写的唯一入口
def db_query(dsn, query):
    tbl = extract_tbl_from_query(query)
    frame = inspect.getframeinfo(inspect.currentframe().f_back)
    print(f"{frame.filename} {frame.function} needs {dsn} {tbl}")
    ...
```

这里具体检查的调用栈层级需要视基础外部依赖加载代码的结构决定.

# 总结

技术项目依赖提取是最为重要的工作, 可以用作增量构建测试, 也便于做结构化的分析和管理.
不光代码文件层面依赖, 数据和代码依赖, 接口和接口依赖, 服务和服务之间依赖, 产品和产品之间的依赖, 也需提取出来进行审查管理.

依赖提取多种手段, 一种是通过额外再写文档的方式备忘记录, 缺点在于很额外的维护工作量, 以及很容易和实际依赖关系产生不一致.
另外一种是, 直接对实际代码/服务做提取. 提取手段分静态分析提取, 和动态调用链提取. 静态提取对于开发规范的执行有很强的要求.
动态提取, 小到单服务级别可以类比profiling技术, 大到系统层面可参考tracing手段.
