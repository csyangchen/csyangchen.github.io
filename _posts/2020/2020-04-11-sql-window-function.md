---
title: SQL窗口函数
---

SQL面向的数据结构: 二维表

窗口: 数据行的上下文

语法

```
func(col) over ([partition by col...] [order by ...] [rows between ...])  
```

- partition: 数据分组
- order by: 组内排序
  - NOTE: 可以是按照计算后的数值排序
  - 如果没有排序, 则是该窗口内全量统计
- rows between: 数据区间
  - 默认是分组内第一行到当前行
  - 可以通过指定数据区间来做移动平均类需求
- func 窗口计算函数:
  - 普通聚合函数
    - 注意不支持去重相关逻辑, 理解为必须是可分治的函数
  - 窗口函数
    - 排行类
        - row_number >= rank >= dense_rank
        - 百分比相关
          - percent_rank = (rank-1) / (total-1)
            - 不算上自己, 落后了多少人
          - cume_dist = count(v <= current_v) / total
            - 1-cume_dist = 比多少人优秀
        - ntile(N): 分桶
          - N只能取常量, 如果N超过窗口行数M, 只取前M个, 不方便
     - 跟据位置取值
        - first_value / nth_value: 相对窗口起始位置
        - last_value: 好像没啥用, 等于当前行数值
        - lag / lead: 相对当前行位置

例子

```
mysql> select *,
    -> row_number() over w,
    -> rank() over w,
    -> dense_rank() over w,
    -> round(cume_dist() over w, 2),
    -> round(percent_rank() over w, 2)
    -> from vs
    -> window w as (order by v)
    -> ;
+----+------+---------------------+---------------+---------------------+------------------------------+---------------------------------+
| ts | v    | row_number() over w | rank() over w | dense_rank() over w | round(cume_dist() over w, 2) | round(percent_rank() over w, 2) |
+----+------+---------------------+---------------+---------------------+------------------------------+---------------------------------+
|  7 |    1 |                   1 |             1 |                   1 |                         0.10 |                            0.00 |
|  4 |    2 |                   2 |             2 |                   2 |                         0.30 |                            0.11 |
|  6 |    2 |                   3 |             2 |                   2 |                         0.30 |                            0.11 |
|  2 |    4 |                   4 |             4 |                   3 |                         0.40 |                            0.33 |
|  5 |    5 |                   5 |             5 |                   4 |                         0.60 |                            0.44 |
| 10 |    5 |                   6 |             5 |                   4 |                         0.60 |                            0.44 |
|  8 |    8 |                   7 |             7 |                   5 |                         0.80 |                            0.67 |
|  9 |    8 |                   8 |             7 |                   5 |                         0.80 |                            0.67 |
|  3 |    9 |                   9 |             9 |                   6 |                         1.00 |                            0.89 |
| 11 |    9 |                  10 |             9 |                   6 |                         1.00 |                            0.89 |
+----+------+---------------------+---------------+---------------------+------------------------------+---------------------------------+
10 rows in set (0.00 sec)


mysql> select *,
    -> sum(v) over (),
    -> sum(v) over w,
    -> round(sum(v) over w / sum(v) over (), 2) as ratio,
    -> max(v) over (order by ts rows between unbounded preceding and 1 preceding) as history_max,
    -> round(avg(v) over (order by ts rows between 3 preceding and current row), 2) as prev_3d_avg,
    -> greatest(lead(v, 1) over w, lead(v, 2) over w, lead(v, 3) over w) as next_3d_max,
    -> v-lag(v) over w as v_diff
    -> from vs
    -> window w as (order by ts)
    -> order by ts
    -> ;
+----+------+----------------+---------------+-------+-------------+-------------+-------------+--------+
| ts | v    | sum(v) over () | sum(v) over w | ratio | history_max | prev_3d_avg | next_3d_max | v_diff |
+----+------+----------------+---------------+-------+-------------+-------------+-------------+--------+
|  2 |    4 |             53 |             4 |  0.08 |        NULL |        4.00 |           9 |   NULL |
|  3 |    9 |             53 |            13 |  0.25 |           4 |        6.50 |           5 |      5 |
|  4 |    2 |             53 |            15 |  0.28 |           9 |        5.00 |           5 |     -7 |
|  5 |    5 |             53 |            20 |  0.38 |           9 |        5.00 |           8 |      3 |
|  6 |    2 |             53 |            22 |  0.42 |           9 |        4.50 |           8 |     -3 |
|  7 |    1 |             53 |            23 |  0.43 |           9 |        2.50 |           8 |     -1 |
|  8 |    8 |             53 |            31 |  0.58 |           9 |        4.00 |           9 |      7 |
|  9 |    8 |             53 |            39 |  0.74 |           9 |        4.75 |        NULL |      0 |
| 10 |    5 |             53 |            44 |  0.83 |           9 |        5.50 |        NULL |     -3 |
| 11 |    9 |             53 |            53 |  1.00 |           9 |        7.50 |        NULL |      4 |
+----+------+----------------+---------------+-------+-------------+-------------+-------------+--------+
10 rows in set (0.00 sec)
```

SQL执行计划阶段

1. where
2. group by
3. having
4. **window**
5. order by
6. limit offset

因此:

- 对于窗口计算结果筛选的, 需要做子查询再筛选
- 可以对计算结果排序截断, 不过一般没啥用

另外窗口函数不能嵌套调用.

# 业务场景

- 积分/微分类需求场景
  - 累积推增量: `v-lag(v) over ... as v_incr`
  - 增量算累积: `sum(v_incr) over ...`
- 移动平均
  - 不支持指定窗口区间的, 自己手写lag后手动求和: `(lag(v, 1, v) + lag(v, 2, v) + lag(v, 3, v)) / 3`
- 同比环比分析等
- 分组榜单计算
- 取历史最近一条记录
- 销量占比分析
- 时序数据清洗
  - 取单增序列: `select * from (select v, max(v) over ... as v_max) where v=v_max`
  - 过滤异常数据点
- 其他实际业务例子DEMO ...

# array_* 实现类似功能套路

Clickhouse暂不支持相关功能

- group by + array_aggs + array_sort 或全局order by 将每个窗口数据合并到一个数组
- array map/reduce 套路, 维护局部状态, 实现相关计算
- array_join 数组换回多行

缺点:

- 全排序+全量数据, 不可控, 在Clickhouse中容易OOM
  - 分组排序, 潜在的分布计算的优化点
  - 窗口计算, 只需要局部可控状态数据支持
- 语法不简洁

# (不)相关SQL特性

grouping sets / cube / rollup

一次性多维度统计汇总.

窗口函数直接计算到每一行:

```
sum(v) over (partition by d1, d2),
sum(v) over (partition by d1),
sum(v) over (partition by d2),
```

with (Common Table Expressions)

个人理解: 子查询临时表别名, 面向过程SQL编程, 避免过深的嵌套子查询的阅读困难

Clickhouse中全局常量的with使用场合, 约等于全窗口计算.

```
with (select sum(bytes) from system.parts where active) as s
select table, sum(bytes) / s from system.parts group by table

select *, s / sum(s) over () from (
select table, sum(bytes) as s from parts group by table
)
```

全窗口计算值应该不会每一行重复计算吧.

# 数据库支持情况

- mysql>=8.0
- presto
  - 不支持窗口区间
- postgresql

# References

- <https://dev.mysql.com/doc/refman/8.0/en/window-functions.html>
- <https://dev.mysql.com/doc/refman/8.0/en/group-by-modifiers.html>
- <https://dev.mysql.com/doc/refman/8.0/en/with.html>
- <https://prestodb.io/docs/current/functions/window.html>
- <https://prestodb.io/docs/current/sql/select.html>
- <https://clickhouse.tech/docs/en/sql_reference/statements/select/>
- <https://www.postgresql.org/docs/current/tutorial-window.html>
