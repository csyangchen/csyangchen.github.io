---
title: Python入口之争
---

Python脚本, 或者Notebook形式, 适合短平快的实验验证, 不适合大规模的工程代码复用.
稍微好一点的, 通过`__name__ == "__main__"`来区分脚本和复用模块场景:

```
def app():
    ...

if __name__ == "__main__":
    app()
```

不过这样写的缺点, 在于需要知道具体入口模块, 此外执行结果依赖加载顺序, 最典型的在于logging模块是否正确全局初始化.

因此, 稍大一点的Python项目, 都需要统一执行入口.

编译型的语言没有这类问题, 因为编译后启动入口一定是唯一的, 没得选择.

Java世界的做法就是开各种`public void static main`入口, 然后包一层shell脚本调用, 还是做得太重.

# Python命令行相关库

之前各项目由于各自为战, 入口启动姿势不统一.

[argparse](https://docs.python.org/3/library/argparse.html) 官方命令行参数解析库, 不需要映入额外的依赖.

[Django构建脚手架](https://docs.djangoproject.com/en/4.0/ref/django-admin/)创建了`manage.py`作为唯一命令行入口

[Celery](https://docs.celeryq.dev/en/stable/getting-started/first-steps-with-celery.html#application)自己维护了一个入口App, 注入相关任务函数, 并支持命令行直接执行

也有很多代码 [fire](https://github.com/google/python-fire) 来做启动, 好处是任意函数都可以不需要装饰直接命令行可调用, 缺点是传入的是模块/函数名, 还是需要调用者知道模块具体文件/命名. 

我们项目的主体沿袭了一个老的flask项目, 并使用用了 [flask-script](https://flask-script.readthedocs.io/)
作为命令管理工具, 因此最小改动沿袭了这个命令行帮助库.

[click](https://click.palletsprojects.com/) 作为flask-script的延续, 完善了flask-script的一些遗留问题, API风格上更加面向函数式编程, 摒弃了之前类继承命令行的做法.

# 现有命令行库的不方便

类似fire, django的命令调用, 动态传入模块/入口函数/类确实方便, 但是缺点在于过于隐式了, 且缺少中间的注册层, 不方便做代码/模块的重构调整.
因为你很难知道/找到代码是怎样被调用的.

click的做法是装饰器方式注册命令, 然而其缺点在于, 一个函数被注解为命令后, 就不能被作为普通函数愉快的调用了.

作为一个合格的装饰器, 不应该改变装饰函数的签名. 装饰器要么:
1. 做一些中间件的处理逻辑, 如请求缓存, 权限校验, 异常捕获记录日志等
2. 做一些触发注册的一些操作, 但是原样返回. 不过这种触发side effect的操作, 个人是不喜欢的, 因为到头来还是要主动加载依赖才能触发

## 函数签名反射生成命令

命令行参数, 包括类型, 默认值, 文档等, 需要额外注解注入, 虽然显式指定了依赖关系, 但是这个重复劳动就太多了.

一个函数不管是代码层面直接调用, 还是命令行调用, 或者HTTP等API方式调用, 区别只是在于交互形式, 具体业务逻辑是没有什么区别的.

因此想法: 反射函数签名来自动生成一个命令类

命令行参数命名等于函数参数名, 用默认值及类型注解推断参数类型, 从函数文档提取对应参数说明.

具体实现利用[inspect](https://docs.python.org/3/library/inspect.html)模块实现.

```python
def make_command(func) -> click.Command:
    """函数反射提取参数生成命令"""
    args, _varargs, _varkw, defaults, _kwonlyargs, _kwonlydefaults, annotations = inspect.getfullargspec(func)
    doc = func.__doc__
    # 函数文档提取说明
    helps_from_doc = dict(re.findall(":param ([a-z0-9_]+): (.*)", doc))
    doc = doc.strip().split("\n")[0]
    kwargs = {}
    if defaults:
        kwargs = dict(zip(*[reversed(l) for l in (args, defaults)]))
    params = []
    for arg in args:
        help = helps_from_doc.get(arg)
        if arg in kwargs:
            default = kwargs[arg]
            is_flag = isinstance(default, bool)
            params.append(click.Option([f"--{arg}"], default=default, help=help, is_flag=is_flag, show_default=True))
        else:
            params.append(click.Option([f"--{arg}"], help=help, type=annotations.get(arg, str)))
    return click.Command(func.__name__, callback=func, params=params, help=doc)

manager = clicks.Group("name")

def command(func):
    manage.add_command(make_command(func))  # 反射函数生成命令并触发命令注册
    return func  # 原样返回不动

@command
def hello(name: str, count=3):
    """实例程序
    :param name: 名字
    :param count: 循环次数
    """
    for _ in range(count):
        print(name)
```

类似方式, 也可以基于函数签名生成文档/API/接口参数校验/...等. 从而实现一处定义, 多处生成.

## 静态依赖和动态加载之权衡

从静态检查的角度来说, 依赖静态注入是最理想的, 缺点是会导致启动耗时显著增加.
在服务类应用, 类似逻辑用于注册路由, 这个是值得的.
但是对于短平快的命令脚本, 可能是得不偿失的.

```python
from path.to.app1
from path.to.app2
# ...

manage = clicks.Group()
manage.add_command(make_command(app1.func1))
manage.add_command(make_command(app1.func2))
manage.add_command(make_command(app2.func3))
# ...
```

以目前项目为例, 主动全部命令主动注册方式依赖加载完成约需5到6秒, 而单个命令加载耗时在0.5到1秒 (视启动的命令依赖的模块多寡波动)

这个和Java项目加载的困境是一样的.

因此为了优化启动速度, 不得不做动态加载, 或者一些基于规则的反射.

```python
cmd2mods = {
    "func1": "path.to.app1.func1",
    "func2": "path.to.app1.func2",
    "func3": "path.to.app2.func3",
    ...
}

def main(args):
    cmd = args[1]
    importlib.import_module(cmd2mods[cmd])  # 为了触发目标命令对应模块注册进来
    manage.main(args)
```

在入口函数不加`@manage`行不行? 可以, 在执行时候包入, 减少了依赖.
但是不太好, 因为命令签名要慎重变更, 加个注解作为显式的提醒.
因此目前项目推行做法就是两处都要写, 入口函数包`@manage`, 以及`cmd2mods`里面也注册一下.

同局部import类似, 都是真的用到的时候才按需加载需要的模块, 但是缺点就是不好做静态的依赖分析, 以及需要非常充分的测试覆盖才能抓取一些恶心的依赖冲突问题.

反射的缺点在于单元测试, 或者变更依赖分析非常难, 因此在测试环境, 我们默认还是全加载的方式, 并作一些基本的检查, 如避免入口冲突等.

## 避免import用于触发注册

变更前

```python
# cat mynet.py
from timm.models.registry import register_model

@register_model
def my_awesome_net():
    pass

# cat model_factory.py
import timm
import path.to.mynet

def get_model(name):
    return timm.create_model(name)
```

变更后

```python
# cat mynet.py
def my_awesome_net():
    pass

# cat model_factory.py
import timm
from timm.models.registry import register_model
from path.to.mynet import my_awesome_net

register_model(my_awesome_net)

def get_model(name):
    return timm.create_model(name)
```

变更后, mynet减少了依赖, 解耦了对于`timm.models.registry`的依赖.
model_factory在pylint检查里面不会报`unused import`检查, 将依赖关系显式表达出来.
在不考虑增量加载的优化下是更优的选择.