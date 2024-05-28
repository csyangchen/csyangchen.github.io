---
title: MySQL 5.7 json data type and virtual column index
tags: mysql
---

投放系统中有单独的广告服务, 所有广告信息相关的增删改查通过该服务接口交互.
由于系统迁移, 需要重新实现这一服务.
在持久化方案设计时, 为了稳妥, 以及考虑到变更通知的需求, 还是决定用我们最熟悉的MySQL来做.

在数据库结构设计时, 希望能够改变之前数据结构设计范式的问题:

1. 数据库多张表存储不同的字段信息, 实际广告结构以proto文件定义, 导致需要和数据库存储表做复杂的映射关系维护
2. 广告字段结构调整时需要相应改表, 这在数据量较大的情况下是个噩梦
3. 广告变更通知是基于消费binlog实现, 需要针对表结构写很多适配代码, 且每次单字段变更又需触发数据库各种连表查询, 才能还原出完整的广告信息, 对于数据库负载压力大, 且没法保障事务性

初步考虑直接将proto格式的广告数据直接以二进制序列化的方式保存.
这样数据库存储层面基本不用关心schema的问题.
而且做CDC的时候基于变更日志就可拿到新的广告信息, 当然缺点就是每个变更日志会很大.

# json payload

然而直接上数据库查查广告信息的需求, 想一想, 还是逃不掉的. 上数据库直接和一堆二进制数据打交道, 想想都刺激.
调研一圈, MySQL生态圈没有很好的能和proto格式交互的方式. 因此退而求其次, 决定以json的方式存储. 缺点:

1. 对字段命名时要万千慎重, 为了保证兼容, 一旦写入, 就不好改了. 而proto里面只认字段ID, 可以随便改成更适合的名字.
2. 实际存储空间更大了.


        create table ads (
            id int primary key,
            payload json not null,
            ct timestamp not null default current_timestamp,
            ut timestamp not null default current_timestamp on update current_timestamp,
            key (ut)
        ) engine=innodb default charset 'utf8mb4' collate 'utf8mb4_bin'
        ;

注意我们使用了ct, ut两个字段, 利用MySQL特性记录创建和更新时间, 并在读取广告信息的时候组装回广告结构里面. 可以针对这两个字段, 结合业务需求进行历史数据淘汰.

MySQL 5.7 增加了对于json类型支持. 因此一些简单的字段提取, 更新操作, 可以直接SQL的方式实现.

        insert into ads (id, payload) values (1, '{"id":1, "status":1, "ader_id":2, "target": {"country": ["US", "CN"]}}');
        select payload from ads where json_contains(payload, '"US"', '$.target.country');
        update ads set payload = json_set(payload, '$.ader_id', 3) where payload->>"$.ader_id"=2;

另外一点使用json格式的好处是, 保证了数据结构的正确性 (至少是有效的json).

从json字段存储实现上来说, json字段存储类似于 varbinary / vartext, 不是 blob / text.
不是单独空间存储 ???

既然以json格存储, 就不要太指望指定字段筛选的效率了, 一定是扫表.

# payload query optimization

然而针对一些重要字段, 还是希望能有索引快速查找.
如广告状态, 绝大部分广告是下线的, 只有少部分在线.
我们还是希望能够快速筛选出在线广告. 一种思路就是回到结构化存储的方式, 另外加一个字段.

这就造成了冗余. 冗余字段的缺点是需要业务逻辑保证数据的一致性. 业务代码维护负担太重.

MySQL 5.7 提供了 generated column, 即基于本行字段计算出来的字段.
只能被查询, 不能被修改, 在关联字段发生更新时自动变更.

        alter table ads add p_status tinyint generated always AS (payload->>"$.status") virtual not null after payload,

注意需要指定数据结构类型, 如果判断字段类型不服, 写入操作会被拒绝. 也支持加not null修饰, 要求该字段必须存在.

一个作用是, 通过generate column的数据结构类型, 以及not null约束, 来一定程度上保证payload的schema的正确性.
另外一个作用是作为一个复杂表达式的一个别名场合使用. 不过最重要的一点是, 我们可以对generated column做索引:

        alter table ads add key (p_status);

virtual修饰符是默认的, 标识不产生实际存储, 只是在查询的时候才会计算出来, 此类被称之为 virtual generated columns.
相对应的, 用stored 来表明产生实际存储.

由于MySQL的索引信息是单独存储, 因此需要做索引的字段, 用virtual标记即可.

配合5.7的查询重写的功能, 我们可以业务代码不改的情况下, 优化部分查询走索引.

        # TODO example needed

# stored generated column as primary key

generated 字段, 默认是 virtual 不能作为主键, 只能用作索引; stored 可以做主键.
我们可以通过这种办法再去掉id字段:
   
        id int generated always as (payload->>'$.id') stored not null,

# partitioning

一种简单办法是对id进行hash分区
       
        create table ads (
            id int generated always as (payload->>'$.id') stored not null,
            dt int generated always as (id % 10) not null,
            payload json not null
        ) partition by hash(id) partitions 32;
       
如果id和创建时间相关, 并且需要定期淘汰, 则可以做范围分区 (RANGE PARTITION).

结合到业务, 我们广告分不同类型, 不同类型的数量级差别很大, 且业务上相对独立. 一个自然的想法就是按照广告类型进行分区.

另外一个种比较hacking的办法, 就是将广告类型编码在了id里面.

        create table ads (
            id int generated always as (payload->>"$.status") stored not null,
            payload json not null,
            p_type tinyint unsigned generated always as (mod(id, 3)) virtual not null
        )
        partition by list(mod(id, 3)) (
            partition s2s values in (1),
            partition api values in (2)
        );

后面实践中反思觉得, 将类型等信息编码在ID中是一个比较糟糕的主意, 太不利于扩展. 而且查询时候需要手动指定分区查询来优化查询速度:

        select payload from ads4 partition (s2s) where payload->>"$.name" ...;

后来想想, 分区键要求必须在主键中, 直接主键里面做冗余可能更好:

        create table ads (
            id int generated always as (payload->>"$.status") stored not null,
            payload json not null,
            p_type tinyint unsigned generated always as (payload->>"$.type") stored not null,
            primary key (id, p_type)
        )
        partition by list(p_type) (
            partition s2s values in (1),
            partition api values in (2)
        );

# generated columns 局限性

- 不能引用自增ID
- 不能适用不确定的函数

所以一下做法是不行的

    create table orders (
        id int auto_increment,
        tid char(12) generated always as (concat(date_format(now(), "%y%m%d"), substring(md5(id), 1, 6))) stored,
        primary key (tid),
        uid int,
        key (id)
    );

绕过办法:

    create table orders (
        ts timestamp(6) not null default current_timestamp(6),
        tid bigint unsigned generated always as (date_format(ts, "%y%m%d%H%f")) stored,
        uid int,
        primary key (tid)
    );

# 总结

涉及到的几个点:

- json fields
- generated column & virtual column index
- partition & subpartition

# Reference

- <https://dev.mysql.com/doc/refman/5.7/en/json.html>
- <https://dev.mysql.com/doc/refman/5.7/en/json-functions.html>
- <https://dev.mysql.com/doc/refman/5.7/en/create-table-generated-columns.html>
- <https://dev.mysql.com/doc/refman/5.7/en/create-table-secondary-indexes.html>
- <https://dev.mysql.com/doc/refman/5.7/en/partitioning.html>
- <https://dev.mysql.com/doc/refman/5.7/en/rewriter-query-rewrite-plugin.html>
- <https://mysqlserverteam.com/indexing-json-documents-via-virtual-columns/>


