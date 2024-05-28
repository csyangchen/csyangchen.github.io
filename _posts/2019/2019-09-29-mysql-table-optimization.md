---
title: MySQL大表优化二则
tags: mysql
---

最近帮另外一个业务组评审数据库表设计, 主要是担心数据量问题, 记录一下.

# 报表类优化

报表类需求, 每天按照不同维度统计, 业务原始表:

    create table report (
        id int primary key auto_increment,
        dt date,
        vid int,
        gid int,
        cnt int not null default 0,
        unique key (dt, vid, gid),
        key (vid, dt),
        key (gid, dt)
    );

由于每天只能有一份统计数据, 所以自然要做唯一性约束.
常见的查询是跟据vid/gid筛选dt一天或者某段时间数据.
由于业务用了django框架的orm, 没办法去掉id字段.
由于数据量级较大, 导致读写非常慢.

建议优化后的表:

    create table report_2 (
        id int auto_increment comment 'deprecated',
        dt date,
        vid int,
        gid int,
        cnt int not null default 0,
        primary key (vid, gid, dt),
        key (gid),
        key (id)
    ) partition by range(to_days(dt))
    subpartition by hash(vid)
    subpartitions 8 (
        partition pYYMMDD values less than maxvalue
    );
   
其中分区由脚本每日定期更新.

注意分区表, 由于索引是每个分区单独创建, 因此不能有唯一索引. 好在自增id本身保证了唯一性, 不用再加唯一约束.
由于数据库每次启动的时候, 要对自增ID取max, 所以必须要对其创建索引. ID字段可以等业务层面彻底抛弃后干掉.

针对vid子分区是为了进一步优化针对vid的点查询, 也可以不要.

分区表的缺点: 索引每个分区单独创建, 所以如果查询涉及到多个分区的时候, 索引查询开销加大.

## 主键顺序问题:

由于每天是按天产生新的数据, 从写入优化角度来说, 对于主键应当是 `primary key (dt, vid, gid)`.
但是由于已经对dt分区, 因此主键字段可以放在最后, 从而省掉对于vid的额外索引.
   
需要把时间字段摆在前面的场景:

1. 顺序写入, 提高写入性能: 因为数据页按照主键顺序排列, 时间放在前面, 顺序写入性能较好好, 避免数据页分裂, 以及频繁的随机写
2. 提高数据页读写内存缓存命中率: 如果主要读写都是是针对最近一段时间的, 那么数据页的内存命中率较高.

例子:

    create table event_log (
        ts datetime,
        id int,
        cnt int not null default 0,
        primary key (ts, id)
    ) partition by range(to_days(ts))
    (partition pYYMMDD values less than maxvalue)
    ;

    select id, sum(cnt) from event_log where ts >= date_sub(now(), interval 3 hour) group by id;

# 用户类表优化

存储每个用户的状态信息, 量级较大, 导致读写很慢:

    create table users (
        uid varchar(64),
        name varchar(64),
        -- omit many fields
        create_time datetime not null,
        update_time datetime not null,
        key (name) using hash,
        primary key (uid)
    );

问题:

- 避免varchar作为主键
- 对于varchar字段尽量用前缀索引
- InnoDB 存储引擎不支持 HASH KEY, 即便声明了也是用 BTREE
- 大表要分区
- 大表不好加字段
- 字段太多, 大部分都是空值, 空间浪费
- 创建/更新时间业务写入端手动维护, 由于时间同步问题, 不能保证递增, 改为由写入时由数据库决定


提议改写后的表:

    create table users_2 (
        uid_crc32 int unsigned generated always as (crc32(uid)) stored,
        uid varchar(64) not null,
        name varchar(64) not null,
        -- omit many fields
        create_time datetime not null default current_timestamp,
        update_time datetime not null default current_timestamp on update current_timestamp,
        key idx_name (name(4)),
        primary key (uid_crc32)
    ) partition by hash(uid_crc32) partitions 32;

不对uid做索引, 通过查询改写掉.

由于业务担心uid冲突问题, 没有采用换上述用`uid_crc32`做主键的方案, 退而求其次使用KEY分区:


    create table users_3 (
        uid varchar(64) not null,
        -- ...
        primary key (uid)
        -- ...
    ) partition by key(uid) partitions 32;
      

## 终极MySQL KV表

    create table kv (
        payload json not null,
   
        p_int tinyint generated always AS (payload->>"$.int") not null,
        key (p_int),
   
        p_str varchar(64) generated always AS (payload->>"$.str"),
        key (p_str(4)),
   
        id int generated always as (payload->>'$.id') stored not null,
        primary key (id)
        ) partition by hash(id) partitions 32;
    );

其中`p_*`字段视筛选条件按需添加, 业务如果改不动可以通过query rewrite掉.

可以视业务情况再做子分区.

## 稀疏字段处理

业务上, 常常因为各别业务需求, 需要增加属性字段.

如果属性字段非常稀疏, 那么将每个字段都单独列, 并不是个很好的注意. 可以通过上述的 json 来只存存在的数据列.

注意对于JSON字段, 不支持增量更新, 必须手动覆盖. 如果业务层面做, 就要开事务, 如果写入SQL语句里面做, 就很丑:

    set payload = json_set(payload, '$.name', 'name')

另外一种业务开发上比较爽的实践:

    create table kv2 (
        id int,
        k int not null comment '键',
        v json not null comment '值',
        primary key (id, k)
    );

且从而每次只筛选出需要的字段, 避免针对payload的全量读写的开销.

k用枚举类表名可能的键值, 并通过键值k来决定v的解析方法. 由业务代码自有裁剪需要拆分的粒度.


# Reference

- 垃圾django不支持多列主键: <https://code.djangoproject.com/wiki/MultipleColumnPrimaryKeys>
- [之前相关的一篇文章](http://www.csyangchen.com/mysql-57-json-virtual-column-index.html)

<!--- TODO relative link --->