---
title: Python单元测试探讨
---

*内部培训大纲*

# 测试意义

- 错误解决成本vs错误解决阶段
- 回归/重构 (对于动态语言尤其重要)
- 功能文档
- 反推代码结构合理化
- ...

# 测试工具

## assert

```
assert 1==1
assert 1==1, "custom assert error message"
```

理解集合比较

```
assert {1, 2, 3} == {3, 2, 1}
assert {"a": 1, "b": 2} == {"b": 2, "a": 1}
```

理解 == / is 区别

正式代码禁止用assert

## [doctest](https://docs.python.org/3/library/doctest.html)

```
def sum(a, b):
    """
    >>> sum(1+2)
    3
    """
```

- PROS: 局部性, 也是文档 便于理解
- CONS: 避免文档写代码, 跳过了代码规则检查

## [unittest](https://docs.python.org/3/library/unittest.html)

[xUnit](https://en.wikipedia.org/wiki/XUnit) for python

TestCase / 测试用例

断言: self.assertXXX

fixture: setUp*/tearDown*
- [setUp vs setUpClass](https://stackoverflow.com/questions/23667610/what-is-the-difference-between-setup-and-setupclass-in-python-unittest)
- 统一在setUp里面做, 避免tearDown里面删数据

(条件)跳过测试
- self.skipTest / @unittest.skipIf(condition, reason)
- 测试依赖外部环境时, 如数据库, 第三方KEY等

TestSuite / 测试集管理

## [mock](https://docs.python.org/3/library/unittest.mock.html)

在一定作用域里面替换掉某些部分的实现逻辑

NOTE: patch到正确的位置:

```
cat path/to/a.py
import requests
from requests import post

def func(url):
    requests.get(url)
    post(url)

cat path/to/a_test.py

@mock.patch("requests.get", MockGetFunc)
@mock.patch("path.to.a.post", MockPostFunc)
def test_func():
    ...
```

原则: 

- 最细粒度mock
- 模块边界mock, 避免mock具体内部实现逻辑

mock外部交互
- [requests-mock](https://requests-mock.readthedocs.io/en/latest/) requests相关
- [moto](http://docs.getmoto.org/en/latest/) OSS/S3相关

## [pytest](https://docs.pytest.org/en/stable/)

- assert结果修饰
- 测试自发现
- unittest兼容, 支持doctest
- 插件生态

*demo time: pytest使用, 运行参数及pytest.ini配置说明*

[mark](https://docs.pytest.org/en/stable/mark.html#mark)

- pytest --markers
- @pytest.mark.xfail
- @pytest.mark.skipif
- @pytest.mark.parametrize vs table_test ???
- ...

测试标签用途`pytest -m`

[fixure](https://docs.pytest.org/en/stable/fixture.html#fixtures)

- DI
- unittest.mock
- unittest.setup*

conftest.py 配置: 基于目录层级, 而非对象继承

### pytest插件说明

- [pytest-benchmark](https://pytest-benchmark.readthedocs.io/en/stable/)
  - 关键路径要有压力测试保障一定性能, 实现优化需要有压测对比说明问题
- pytest-coverage
- pytest-flaky

## prefer pytest over unittest

```
# DONT
self.assertXXX
# DO
assert ...

# DONT
with self.assertRaises(...):
    ...
# DO
with pytest.raise(...):
    ...

# DONT
if XXX:
    self.skipTest
# DONT
@unittest.skipIf(condition, reason)

# DO
@pytest.mark.skipif(condition, reason)
# DO (in DJ)
@require(service_dsn)

# DONT
@unittest.expectedFailure
# DO
@pytest.mark.xfail(...)
```

避免使用unittest, 尽量使用pytest理由: 
- 类继承把代码做复杂了. pytest对于代码倾入性较少.
- **不**建议面向对象编程.
- 对应的pytest方法都能满足需求.

## coverage

[原理](https://coverage.readthedocs.io/en/coverage-5.2.1/howitworks.html)

结果写 .coverage SQLite数据库, 依赖py代码做后续报告分析

基于stmt/语句统计, 小于代码行数: 格式化多行, 空行/注释不纳入统计

和测试无关, 可以线上程序coverage跑覆盖率, 找dead code

分目录测试并看覆盖: pytest --cov path path

ref: [.coveragerc](https://coverage.readthedocs.io/en/v4.5.x/config.html]

*demo time*

未覆盖代码的意义:

- 潜在bug, 或未约束明确的功能逻辑
- dead code: 从未覆盖的代码反向思考真正有用的逻辑是哪些, 简化代码逻辑.

覆盖率 != 正确性/代码质量, 单纯加载全部全py文件都能有不错的覆盖率, 需要有正确的断言逻辑

不必追求100%测试率, 视业务严肃性决定, 完美vs及时交付的平衡, 缺陷成本意识

避免只有测试中才访问到的功能, 简化维护敞口 (参考项目vulture配置).

# 如何写测试

*难以测试的代码 = 糟糕的代码结构*

良好测试代码的评价标准: 修改代码行数 / 需要修改的测试代码行数
- 过低: 很多逻辑没有充分测试覆盖到
- 过高: 
  - 修改导致既有测试用例失败, 新功能引入的回归性不好, 或者说功能设计没有考虑到向未来兼容
  - 过于脆弱, 不鲁棒, 测试用例偏向面向实现细节测试, 没有针对长期较为稳定的模式/边界测试

测试边界问题 -> 代码模块/边界识别
- 数据处理类功能: 初始数据库准备, 最终数据库数据断言
- web接口类功能: 请求回放, 返回内容断言

## FIRST原则和对应实践

- **F**ast:
  - DDL批量执行加速数据准备
  - mock掉外部请求, 断网可测 (也是为了IR)
  - 加速变更反馈, 加速迭代
  - ...
- **I**ndepedent:
  - 用docker-compose构建确定的测试环境
  - mock外部服务依赖
  - 用pytest-randomly发现隐含依赖
- **R**epeatable:
  - 避免随机性
  - 测试前做清洗
  - mock时间相关
- **S**elf-Validating
  - 测试一定要做断言, 不是跑完人工看输出是否符合预期
- **T**imely: 
  - 测试先于具体开发

# 相关思潮

*我要开始装逼了*

- **TDD**: [Test Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)
  - XP 尽早反馈调整
    - 极限: 代码修改触发自动相关测试重跑
  - **先写测试**, 而不是功能完成后补测试
  - 红绿灯迭代意识
- **TDT / DDT**: Table Driven Test / Data Driven Test 
  - 数据驱动测试, 识别输入/输出模式, 避免写测试代码
- **SBE**: [Specification By Example](https://en.wikipedia.org/wiki/Specification_by_example)
  - 避免写文档, 写通俗易懂的, 可执行验证的测试例子, 快速上手使用
- **BDD** (DDD)
  - GWT (Given / When / Then)
  - 数据任务GWT: 
    - SQL就是数据任务最简洁的领域语言
    - SQL查询结果断言语法
- ATDD / STDD / ...

更多测试名词轰炸:
- Unit Testing 
- Smoke Testing
- Integration Testing 
- Regression Testing
- Acceptance Testing
- 区别: 测试的范畴
