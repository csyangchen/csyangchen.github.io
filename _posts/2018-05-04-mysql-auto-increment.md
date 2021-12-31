---
title: 从一个MySQL自增ID字段溢出问题引发的讨论
tags: mysql
---

# 引子

线上报表出现数据差异, 排查一圈发现并没有写入报错. 语句大概这样:

	    insert into report_summary select ... from report_detail on duplicate key update ...

看了一下表结构

        create table report_summary (
            id int unsigned auto_increment primary key,
            dt datetime,
            oid int,
            ...
            UNIQUE KEY (dt, oid, ...)
        ) ENGINE=InnoDB AUTO_INCREMENT=4294967295 DEFAULT CHARSET=utf8

等等, 4294967295 这个看上去有点可疑, 看上去是自增ID字段溢出了.

然而, 然而, 再自增ID溢出的情况下, 返回的错误是

        ERROR 1062 (23000): Duplicate entry '4294967295' for key 'PRIMARY'

所以 ON DUPLICATE KEY UPDATE 错误更新了其他列. 并不返回错误.

问题找到, 一开始打算尝试线上该表, id 改成 bigint. 但是该表开销太大. 放弃. 重建一张表, rename 后确保线上正常继续写入, 并从旧表导入历史数据.

CASE CLOSED.

# 理解 AUTO_INCREMENT

概念上于每次插入时自动赋值为 max(id)+1. 可以主动赋值, 可以比当前最大值要小, 甚至可以重复.

AUTO_INCREMENT 可以不是主键, 但必须作为KEY 不要求是UNIQUE. 一个表只能有一个 AUTO_INCREMENT 修饰字段.

因此, 不要将 AUTO_INCREMENT 和 PRIMARY KEY 或者 UNIQUE 等同起来.

AUTO_INCREMENT 一定是要作为 KEY 是基于其实现上的考虑.

例子: `create table xxoo (id int auto_increment, a int, b int, primary key (a, b), [unique ]key (id));`

# 自增ID + 唯一索引的问题

后台同学由于一些ORM的原因, 表特别喜欢这样设计.

写入时, 先生成主键自增ID, 检查唯一约束, 如果不符合, 则写入失败. 但是已经增加的ID不会收回.
这就会导致自增ID会浪费很多范围.

例子:

        > create table t (id int auto_increment primary key, dim int not null default 0, unique key (dim));
        OK
        > insert into t (dim) values (1);
        OK
        > insert into t (dim) values (1);
        ERROR 1062 (23000): Duplicate entry '1' for key 'dim'
        > insert into t (dim) values (2);
        OK
        > select * from t;
        +----+-----+
        | id | dim |
        +----+-----+
        |  1 |   1 |
        |  3 |   2 |
        +----+-----+

可以看到自增ID跳过了2. 意不意外, 惊不惊喜?

## 原因分析

简单来想, 在每个事务期间, 应当持有自增ID计数器的锁, 即相当于持有全表锁. 但是这样的实现并发性能很差.
因此InnoDB默认的实现方式是使用了更轻量的锁. 确保了同时执行的写入事务(不论单条还是批量)不会拿到重复的自增ID, 当然缺点就是当没有真正写入时, 自增ID会不连续.

`innodb_autoinc_lock_mode` 参数是数据库配置文件选项, 没法针对单个表进行设置.

此外, 自增ID对于事务回滚不能很好支持. 参考MySQL文档中的说明:

> In all lock modes (0, 1, and 2), if a transaction that generated auto-increment values rolls back, those auto-increment values are “lost”. Once a value is generated for an auto-increment column, it cannot be rolled back, whether or not the “INSERT-like” statement is completed, and whether or not the containing transaction is rolled back. Such lost values are not reused. Thus, there may be gaps in the values stored in an AUTO_INCREMENT column of a table.

## CASE 1

利用自增ID生成唯一的ID, 当时需要跟据一些维度信息来去重. 实现方式:

        create table ids (id int auto_increment primary key, digest varchar(64), unique key (digest))

        insert into table ids set digest = 'pkg-country-os'
        # 判断如果返回错误, 则认为已经存在, 取出旧的ID; 否则返回last_insert_id.
        select id from ids where digest = 'pkg-country-os'
	
为了节约ID, 正确的方式应当是, 先查询, 如果不存在, 再写入. 当然这种方式需要事务, 对于事务等级要求比较高. 不展开.

另外一种方式, 使用一张辅助表实现 ([来源](https://www.percona.com/blog/2011/11/29/avoiding-auto-increment-holes-on-innodb-with-insert-ignore/)):


        create table mutex (i int primary key);
        insert into mutex(i) values (1);

        insert into ids (digest) select @digest from mutex left outer join ids on digest=@digest where i=1 and digest is null;

思路是通过连表查询来判断是否存在, 如果不存在, `select` 语句才有效, 从而生成一次有效的写入.

# CASE 2

和我们出现问题的例子类似, 业务中经常见到的这样的报表结构

        create table report (
            id int auto_increment primary key,
            dt date,
            aid int not null default 0,
            cnt int not null default 0,
            unique key (dt, aid)
        );

        -- 更新语句例子

        insert into report (dt, aid, cnt) values ('2018-05-04', 1, 1), ('2018-05-04', 2, 1) on duplicate key update cnt = values(cnt);
        +----+------------+-----+-----+
        | id | dt         | aid | cnt |
        +----+------------+-----+-----+
        |  1 | 2018-05-04 |   1 |   1 |
        |  2 | 2018-05-04 |   2 |   1 |
        +----+------------+-----+-----+

        insert into report (dt, aid, cnt) values ('2018-05-04', 2, 2), ('2018-05-04', 3, 2) on duplicate key update cnt = values(cnt);

        +----+------------+-----+-----+
        | id | dt         | aid | cnt |
        +----+------------+-----+-----+
        |  1 | 2018-05-04 |   1 |   1 |
        |  2 | 2018-05-04 |   2 |   2 |
        |  3 | 2018-05-04 |   3 |   2 |
        +----+------------+-----+-----+

        insert into report (dt, aid, cnt) values ('2018-05-04', 4, 4), ('2018-05-04', 4, 4) on duplicate key update cnt = values(cnt);

        +----+------------+-----+-----+
        | id | dt         | aid | cnt |
        +----+------------+-----+-----+
        |  1 | 2018-05-04 |   1 |   1 |
        |  2 | 2018-05-04 |   2 |   2 |
        |  3 | 2018-05-04 |   3 |   2 |
        |  5 | 2018-05-04 |   4 |   4 |
        +----+------------+-----+-----+

可以看到, 批量写入时, 如果单行更新发生冲突, 并不影响ID的连续性, 因为这里会利用了 bulk inserts 的特性. 但是后续的写入还是会有跳跃的情况.

因此 不要想当然的以为自增ID范围应该够用. 自增ID等于更新的次数, 不等于数据行数. 在上述更新操作非常频繁的情况下, 自增ID溢出也不是小概率事件.

# 如何设计报表结构?

推荐报表以时间作为主键, 并跟据时间分区. 基于几个原因:

- 报表查询特点: 一般而言, 一定会有一个时间段范围筛选条件. 多数时查询近期时间段.
- 对于InnoDB引擎, 数据存储是按照主键顺序组织. 报表查询一定是一段连续时间的数据查询
- 每个分区单独一个表存储, 包括索引/锁等, 都是基于单个分区表实现. 由于时间数据的明显冷热性, 对于历史分区表的批量操作不会影响当前分区表的频繁读写. 从而避免锁.
- 索引是基于每个分区构建的, 当数据量比较大时, 单分区的索引相对而言会比较小, 效率更高.
- parition pruning, 对于时间范围落在单个分区内的查询, 只需要查询单个分区表.

另外一个更重要的原因是数据页缓存和预读机制(Prefetching / Read-Ahead).
数据页缓存机制和操作系统的虚拟内存机制类似, 查询的时候, 先查询内存加载的数据页是否命中, 若不命中采取查询磁盘.
此外数据页预读机制会将连续的数据页在后台主动读取, 从而提高命中率.
数据库的一个重要指标就是缓存页命中率, 正常来说接近100%才比较合理.

# 线上DDL注意

背景: 发现该问题后尝试直接线上DDL修正, 结果当然很悲剧, 快速解决的做法是换新表同步数据进去.

MySQL 不支持 non blocking ddl, 因此线上大表的调整, 需要特别谨慎.

改表结构时, 会锁全表, 发生全拷贝, 相当于重建一张表.

例外的一些情况: 修改字段注释, 调整约束等, 只需要修改表的元信息, 实际表数据不发生调整.

percona toolkit 有增量拷贝的工具, 其方法是创建一张相同表, 通过触发器等方式增量更新, 小步同步数据.

重建一张表, 可以先去掉索引, 以优化写入性能, 当数据批量导入后, 再一次性创建索引, 效率更高.

MySQL 对于DDL的事务支持不好, 不能原子性的重命名两张表. 所以在该表的过程中, 写入有短期的table not found错误.

# 结论

请不要用自增ID+唯一索引设计表!!!
如果一定要用, 并且主要查询是通过唯一索引字段的话, 请用唯一索引字段作为主键, 自增ID当作唯一索引, 这样减少一次通过二级索引查询主键的操作.

涉及时间相关的效果数据等表设计, 请以时间为主键(第一列), 并考虑按照时间范围分区. (如果分区粒度和最细统计维度都是天的话, 日期字段就不用放在第一列, 摆在最后就可以了, 给其他维度一个走索引的机会).

# Reference

- <https://dev.mysql.com/doc/refman/8.0/en/innodb-auto-increment-handling.html>
- <https://www.percona.com/blog/2017/07/26/what-is-innodb_autoinc_lock_mode-and-why-should-i-care/>
