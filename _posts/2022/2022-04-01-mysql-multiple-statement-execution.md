---
title: MySQL多语句执行
---

后端服务性能优化的归宿在于减少外部交互, 能走队列逻辑的走队列异步化, 以及走任务批处理.


之前对于Redis缓存读写逻辑的优化, 就利用了[PIPELINING](https://redis.io/docs/manual/pipelining/)特性, 显著提升耗时. 压测对比:

```
--------------------------------------------------------------------------------------------- benchmark: 2 tests --------------------------------------------------------------------------------------------
Name (time in us)                 Min                   Max                  Mean              StdDev                Median                 IQR            Outliers         OPS            Rounds  Iterations
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
test_redis_pipeline          608.4840 (1.0)      1,538.8770 (1.0)        771.8566 (1.0)      233.0769 (1.0)        660.5025 (1.0)       76.7880 (1.0)       101;123  1,295.5775 (1.0)         622           1
test_redis_no_pipeline     5,393.8120 (8.86)     8,637.5380 (5.61)     6,403.9163 (8.30)     705.3805 (3.03)     6,264.3720 (9.48)     839.2775 (10.93)        26;3    156.1544 (0.12)         80           1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

数据库批量读写可以通过事务次数, 以及网络通讯次数提升性能, 所以很多时候, 我们会写如下的批量读写语句优化SQL交互:

```
# IN查询一次性查一批数据出来
select ... from ... where id in (...);
# 单语句批量写入
insert into table ... values (...), (...), (...);
```

但是, 对于update语句, 看上去似乎无法一条语句批量执行

```
update table set v=... where k=1;
update table set v=... where k=2;
...
```

有其他办法么? MySQL支持[多语句执行](https://dev.mysql.com/doc/c-api/5.7/en/c-api-multiple-queries.html),
即不需要执行一条等一条执行结果, 而是一次性发送一批执行语句给服务器, 再依次解析每个语句的执行结果.

该功能需要客户端链接时主动开启.

测试数据 (1000行数据写入/更新逻辑)

```
# python3.8/pymysql/mysql1
单语句写入 duration=51.125 aff=1000
多语句写入 duration=50.800 aff=1000
单语句批量写入(自行拼SQL) duration=0.091 aff=1000
单语句批量写入(executemany) duration=0.101 aff=1000
单语句更新 duration=46.349 aff=1000
多语句更新 duration=46.422 aff=1000
# python3.8/mysqlclient/mysql1
单语句写入 duration=48.927 aff=1000
多语句写入 duration=46.919 aff=1000
单语句批量写入(自行拼SQL) duration=0.090 aff=1000
单语句批量写入(executemany) duration=0.109 aff=1000
单语句更新 duration=48.027 aff=1000
多语句更新 duration=61.536 aff=1000
# go1.18/go-sql-driver/mysql1
单语句写入 54.8775449s 1000
(prepared)单语句写入 52.2021368s 1000
多语句写入 46.3095607s 1
单语句更新 50.0363546s 1000
(prepared)单语句更新 47.3770595s 1000
多语句更新 48.3637597s 1
# python3.8/pymysql/mysql2
单语句写入 duration=1.615 aff=1000
多语句写入 duration=1.441 aff=1000
单语句批量写入(自行拼SQL) duration=0.008 aff=1000
单语句批量写入(executemany) duration=0.014 aff=1000
单语句更新 duration=1.651 aff=1000
多语句更新 duration=1.551 aff=1000
# python3.8/mysqlclient/mysql2
单语句写入 duration=1.584 aff=1000
多语句写入 duration=1.431 aff=1000
单语句批量写入(自行拼SQL) duration=0.006 aff=1000
单语句批量写入(executemany) duration=0.011 aff=1000
单语句更新 duration=1.632 aff=1000
多语句更新 duration=1.502 aff=1000
# go1.18/go-sql-driver/mysql2
单语句写入 1.844254185s 1000
(prepared)单语句写入 1.546443549s 1000
多语句写入 1.431203002s 1
单语句更新 1.922612132s 1000
(prepared)单语句更新 1.598375335s 1000
多语句更新 1.548532195s 1
# python3.8/pymysql/mysql3
单语句写入 duration=1.615 aff=1000
多语句写入 duration=1.441 aff=1000
单语句批量写入(自行拼SQL) duration=0.008 aff=1000
单语句批量写入(executemany) duration=0.014 aff=1000
单语句更新 duration=1.651 aff=1000
多语句更新 duration=1.551 aff=1000
# python3.8/mysqlclient/mysql3
单语句写入 duration=1.584 aff=1000
多语句写入 duration=1.431 aff=1000
单语句批量写入(自行拼SQL) duration=0.006 aff=1000
单语句批量写入(executemany) duration=0.011 aff=1000
单语句更新 duration=1.632 aff=1000
多语句更新 duration=1.502 aff=1000
# go1.18/go-sql-driver/mysql3
单语句写入 1.844254185s 1000
(prepared)单语句写入 1.546443549s 1000
多语句写入 1.431203002s 1
单语句更新 1.922612132s 1000
(prepared)单语句更新 1.598375335s 1000
多语句更新 1.548532195s 1
```

测试结果分析

单语句批量写入耗时一骑绝尘, 单语句批量写入只是一个执行事务, 且只需返回一个结果, 可能是其速度极快的因素.

客户端实现方式:
- [pymysql](https://github.com/PyMySQL/PyMySQL) 纯Python的客户端库
- [mysqlclient](https://github.com/PyMySQL/mysqlclient) 基于MySQL C API的实现, 想着应该会性能好一些
- Golang 想着肯定比 "垃圾" Python 强一些

测试下来, 客户端实现对于结果影响不大, 甚至可能由于抖动的因素导致的反预期.

多语句/单语句耗时统计
- mysql1: 机械硬盘mysql / 非本机: 300s / 299.34 = 100.3%
- mysql2: 固态硬盘mysql / 非本机: 8.9s / 10.25s = 86.9%
- mysql3: 固态硬盘mysql / 本机: 8.9s / 10.31s = 86.3%

并没有预想类似Redis PIPELINE的显著效果. 分析原因是, 数据库执行的事务IO开销是主要矛盾, 网络通讯已不是的主要矛盾了.

固态硬盘mysql性能会好不少, 才体现出了一点多语句加速效果. 内网环境下, 本机/非本机网络测试上没有体现出差别.

# pymsql多语句支持

pymysql库的`execute`逻辑是面向单语句执行设计. 对于多语句执行的结果, 只记录了第一条结果返回. 如何拿到批量执行多条语句的结果呢?

看一下MySQL的写交互流程, 正常流程下都是简单的一问一答机制:

- 发送请求消息 [COM_QUERY](https://dev.mysql.com/doc/internals/en/com-query.html#packet-COM_QUERY)
- 收到响应消息 [COM_QUERY_Response](https://dev.mysql.com/doc/internals/en/com-query-response.html#packet-COM_QUERY_Response)
  - 对于正常写入语句返回的是 [OK_Packet](https://dev.mysql.com/doc/internals/en/packet-OK_Packet.html),
    包含了影响行数, 写入自增ID等信息,
    其中 `status_flag & SERVER_MORE_RESULTS_EXISTS` 标记是否还有消息, 如果有的话客户端应该继续消费完

然而, pymysql每次执行的时候忽略了未消费完的消息

```
def execute(self, query, args=None):
    while self.nextset():
        pass
    # ...
```

为了拿到每条执行结果总共影响行数, 只需要增加遍历结果计数即可

```
def execute_multi(curr, query):
    aff = curr.execute(query)
    while curr.nextset():
        aff += curr.rowcount
    return aff
```

此外也可以针对每个执行语句返回对应的结果, 如查询数据迭代器, 批量写入的具体自增ID等等, 这里就不展开了.

Go版本测试多语句执行影响行数返回1, 也是因为只处理了单消息, 然后丢弃了剩余消息导致. 不过不太好注入拿到全部结果.

# 衍生: prepared statement 优化性能

MySQL读写的另外优化手段是使用 prepared statement, 即把SQL执行计划提前发送并缓存在数据库, 拿到statement_id, 后续每次只用传statement_id及参数即可.

- 优点在于: 1. 避免SQL注入 2. 减少通讯传输开销 3. 节约SQL解析计算开销.
- 缺点在于: 需要额外维护状态所引入的复杂性.

上面Go版的测试`(prepared)`标记了对应的测试结果, 可以看到, 对于单语句有非常显著的提升.