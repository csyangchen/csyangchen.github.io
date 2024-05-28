---
title: Python assert 行为不一致原因分析
---

最近做一些测试, 由于习惯性pytest跑代码, 得到了非预期的结果. 表现如下

```
> cat a.py
assert 'ab' is 'a'+'b'
> python a.py
# PASS
> pytest a.py
E   AssertionError: assert 'ab' is ('a' + 'b')
```

一通问题定位下来, 发现是pytest对于assert语句做了改写导致.

pytest为什么要改写assert语句? 为了断言失败的时候输出更多有用的信息. 比如说序列断言相等失败时, diff定位到具体导致不同的元素.

pytest如何改写assert语句的? 利用模块加载时候的钩子函数, 改写了实际加载的代码中的assert语句逻辑.
assert语句本身比较简单, (left, op, right) 的三元结构, 当然需要根据具体语句做不同的特化处理.
也支持通过conftest自行写`pytest_assertrepr_compare`来改写断言失败的输出.

如何看pytest改写后的语句?

```
import ast
from _pytest.assertion.rewrite import AssertionRewriter

code = """assert 'ab' is 'a'+'b'"""
mod = ast.parse(code)
print(ast.unparse(mod))
AssertionRewriter(None, None, code).run(mod)
print(ast.unparse(mod))
```

输出

```
assert 'ab' is 'a' + 'b'
import builtins as @py_builtins
import _pytest.assertion.rewrite as @pytest_ar
@py_assert0 = 'ab'
@py_assert3 = 'a'
@py_assert5 = 'b'
@py_assert7 = @py_assert3 + @py_assert5
@py_assert2 = @py_assert0 is @py_assert7
if not @py_assert2:
    @py_format8 = @pytest_ar._call_reprcompare(('is',), (@py_assert2,), ('%(py1)s is (%(py4)s + %(py6)s)',), (@py_assert0, @py_assert7)) % {'py1': @pytest_ar._saferepr(@py_assert0), 'py4': @pytest_ar._saferepr(@py_assert3), 'py6': @pytest_ar._saferepr(@py_assert5)}
    @py_format10 = ('' + 'assert %(py9)s') % {'py9': @py_format8}
    raise AssertionError(@pytest_ar._format_explanation(@py_format10))
@py_assert0 = @py_assert2 = @py_assert3 = @py_assert5 = @py_assert7 = None
```

翻译一下

```
v0 = 'ab'
v3 = 'a'
v5 = 'b'
v7 = v3 + v5
assert v0 is v7
```

可见常量表达式改写成了变量运算结果, 自然断言失败

为什么`'ab' is 'a' + 'b'? 因为做了常量折叠优化

```
import dis
dis.dis(lambda: 'ab' is 'a' + 'b')

  2           0 RESUME                   0
              2 LOAD_CONST               1 ('ab')
              4 LOAD_CONST               1 ('ab')
              6 IS_OP                    0
              8 RETURN_VALUE

```

如何确保pytest的assert和实际执行一致? `--assert plain`关掉全部assert改写, 或者指定模块文档加`PYTEST_DONT_REWRITE`标记忽略改写.

衍生为什么代码里面 assert 是个糟糕的主意? `__debug__`参数决定了是否执行assert语句.
`python -O` 时, `__debug__ = False`, 会不执行`assert`语句.
相信不会有人真的`python -O`跑代码吧?
正式代码里面的校验老老实实写`if not ...: raise XXX`比较稳妥, 至少可以通过XXX抓出来抛对应抛异常的地方

# Reference

- <https://pytest.org/en/7.4.x/how-to/assert.html#advanced-assertion-introspection>
- <https://docs.pytest.org/en/latest/how-to/writing_plugins.html#assertion-rewriting>