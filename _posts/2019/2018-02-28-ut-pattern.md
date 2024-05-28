---
title: 报表增量更新UT模式
---

# 解决问题

0. "报表"这里理解为缓存表, 可以随时从其他"事实表"重新计算得到
1. B报表依赖A数据源时候, 数据一致性问题
2. 以及在订正数据的时候, 所有关联报表的自动更新机制

对于汇总数据, 最简单的方式是创建视图, 但是数据量大时, 对于视图的查询过滤会非常慢, 所以需要将常见聚合查询结果缓存下来.

可以使用类似物化视图. 不过物化视图的实现方式一般是全量的, 而且是每次更新触发的, 会导致性能非常差. 另外也不灵活.

所以业务上一般的做法, 还是根据不同数据需求, 做不同的报表.

# UT模式简介

一般而言, 日志会有一个发生时间（如点击时间, 回调时间戳）, 和实际更新到数据库时间区别, 为了可重跑性, 一般按照日志发生时间来统计报表.

每个数据源/报表每条字段有个最后更新时间戳(ut).
依赖于A数据源的下游表B, 定期执行汇总查询操作同步数据, 在每次统计的时候记录上次最后同步的ut.

每次执行时：

1. 读取上次同步UT, 记为 last_ut
2. 获取上游表当前更新时间戳 curr_ut
  - 注意不能去本地时间, 为了避免各系统时间误差
  - 注意再严谨点不能直接取`select now()`, 而应该取`select max(ut) from src_table`
3. 统计上游表在 (last_ut, curr_ut] (注意左开右闭区间为了避免重复消费) 时间段内更新所影响的主键维度(一般而言是时间统计时间)
4. 将该更新时间段影响的统计数据进行重跑

这里ut实际上当作消息队列消费的游标位置 (Sequence Number), 只不过我们吧时间戳当作单增游标用.
这里不需要保证每一条数据的游标唯一性, 因为一批次更新的数据使用同一个ut没有问题.

# 说明

- 对于UT字段要求：不能删除行, 不能直接改主键 (隐含了删除逻辑), 否则会导致改变更被漏掉. 可以通过无效标记位, 金额/指标置零的方式抹掉该行记录并触发同步下游.
- 为了减少每次更新涉及的数据量, 可以在统计维度上进一步细化.
- 为了确保时间的单调递增, 严禁业务程序写入ut字段, 由数据库摄入数据时取当前时间.
- ut字段必须做索引, 也可以结合其他关心的字段做联合索引.
- 注意只能通过ut及主键字段做筛选, 额外的非主键筛选条件一不小心就会引入统计错误.
- 严谨来说, 极端情况下 (事务问题), 会有读取到`curr_ut`后, 仍然有数据行修改发生在`curr_ut`, 导致上面左开右闭的方式会漏更新数据.
  缓解办法是`ut between $last_ut and $curr_ut`的方式取数, 但是下游更新需要保证覆盖更新, 不能做增量, 因为发生在`curr_ut`的事件会重复计算.


# MySQL例子

```
-- 订单表
create table orders (
    tid int,
    uid int comment '账号',
    gid int comment '产品',
    amount decimal(8,2) comment '金额',
    status tinyint default 0 comment '状态: 0未付款/1到账/2退款/...',
    ct timestamp not null,
    ut timestamp not null default current_timestamp on update current_timestamp,

    dt char(10) generated always as (date(ct)) virtual,
    primary key (tid),
    key (ut, dt, gid)
);

-- 报表(缓存表)
create table income (
    dt date,
    gid int,
    income decimal(8,2),
    ut timestamp not null default current_timestamp on update current_timestamp,
    key (ut),
    primary key (dt, gid)
);

-- 定时统计任务, 即便历史上一条订单状态变更了也会统计到
-- 注意不能跟据status做where筛选, 也不能做having过滤
select now() as @curr_ut;
insert into income (dt, gid, income)
select dt, gid, sum(case status when 1 then amount else 0 end) as income from orders
where (dt, gid) in (select distinct dt, gid from orders where ut between @last_ut and @curr_ut)
-- and status=1
group by dt, gid
-- having income > 0
on duplicate key update income = values(income)
;

```
