---
title: PostgreSQL 初体验
tags: psql
---

PostgreSQL比MySQL有着更加悠久的历史, 但是感觉没有MySQL更加普及. 
PostgreSQL宣传自己是企业级的开源数据库, 今天我们就来体验一下, 其到底有什么有趣的特性.
    
## 更好的约束

除了唯一键约束(unique index), 外键约束(foreign key constraints), 非空约束(not null)外, 
PostgreSQL还支持基于表达式的约束(check constraints), 以及基于表达式的唯一性约束(exclusion constraint).
注意MySQL支持对于数值型字段加unsigned约束, 但这不是标准SQL的一部分.
另外, 经常提到的主键约束(primary key), 可以理解为唯一约束加上非空约束.

看一个例子:

    create table flow (
        month char(7) check (month similar to '\d{4}-\d{2}'),
        initial integer check ((initial >= 0) and (initial < 100)),
        gain integer check (gain > 0),
        cost integer check (cost > 0),
        remain integer check (remain >= 0),
        constraint custom_check_name_here check (initial + gain - cost = remain),
        primary key (month)
    );

对于每列数据, 我们可以进行更加细化的约束. 我们也可以将行内约束关系的约束表达出来. 
虽然我们可以在业务逻辑里面保证这些关系, 但是约束检查离存储越近, 我们越安心.

## 物化视图支持 (Materialized Views)

在报表开发中, 视图(view)可以帮助我们解决同一份数据, 不同粒度观察时的一致性问题.
但是由于查询计划实际还是执行在原始表上, 因而在数据量大时, 执行会很慢.
这时候, 我们就需要物化视图将数据落地, 并可以创建合适的索引, 从而提高查询效率.

    create table income_day (
        recdate char(10) primary key,
        income numeric(2)
    );
    
    create materialized view v_income_month as
    select
        substring(recdate from 1 for 7) as recmonth,
        sum(income) as income
    from
        income_day
    group by
        recmonth
    ;

    create unique index idx_income_month on v_income_month (recmonth);

    insert into income_day ...
    
    refresh materialized view v_income_month;
    
刷新物化视图的操作可以通过触发器执行, 也可以定时执行.

在MySQL里, 我曾经这样做过: 
创建 income_month 表, 字段和 v_income_month 相同;
在更改 income_day 后, 执行`delete from income_month; insert income_month select * from v_income_month`. 
但是当 income_day 频繁跟新时, 这种暴力的数据落地写入太慢.
*相信* `refresh materialized view` 可以比这中方式做的更好.

## 更好的索引

### Online DDL

在线上做DDL操作时, 经常担心会导致锁表. PostgreSQL在创建索引的时候, 可以通过添加`concurrently`修饰, 来避免索引导致DML阻塞. 
当然公平来说, MySQL5.6之后, InnoDB对于Online DDL有了更好的[支持](http://dev.mysql.com/doc/refman/5.6/en/innodb-online-ddl.html).

### 多种类型的索引

除了B-tree索引, PostgreSQL还支持hash等索引结构. 虽然B-tree索引在绝大多数情况下够用了, 但是hash索引可以提供更好的点查询性能.

### 可以利用到多个索引

公平来说, 这点MySQL从5.0后也有, 即[Index Merge Optimization](http://dev.mysql.com/doc/refman/5.6/en/index-merge-optimization.html), 但是似乎被提及的比较少.
PostgreSQL可以将查询条件, 根据不同索引进行分解, 并将查询结果通过bitmap的方式进行(and / or)操作合并. 

另外提一下多重索引(Multicolumn Indexes), 在设计时需要特别注意列顺序. 在一定条件下, 多重索引必然比使用多个索引要快. 可以参考<http://www.percona.com/blog/2009/09/19/multi-column-indexes-vs-index-merge/>.

### 函数索引 (Indexes on Expressions)

这点非常有用, 因为一旦该列被纳入了函数计算, 那么久没法用到该列的索引了. 所以我们在设计查询表时, 有时候为了查询方便, 或者查询速度的考虑, 常常不遵循第二范式, 在行内设计一些冗余字段, 如:

    create table reglog (
        rectime int comment '注册时间',
        recdate char(10) comment '注册日期',
        username varchar(50),
        index (recdate)
    );
    
这样我们在查询某一天的数据时, 只要查recdate就可以了.
但是这样手动添加的冗余字段会给我们带来维护的问题, 需要保证recdate和rectime的对应关系.

或者我们也可以对rectime做索引, 并且在查询时使用 `where recdate between unix_timestamp('recdate 00:00:00') and unix_timestamp('recdate 23:59:59')`. 不过这里, 对于分布很散的列, 我猜会导致索引很大.

在PostgreSQL里, 我们可以通过创建函数索引, 让维护一致性的事情交由数据库去做.

    create table reglog (
        rectime int,
        username varchar(50)
    );
    
用到的函数必须是immutable的, 这里我们创建一个函数先

    create or replace function to_recdate(rectime int) 
        returns char(10)
        language sql
        immutable
    as
    $body$
        select to_char(to_timestamp(rectime) at time zone 'UTC-8', 'YYYY-MM-DD');
    $body$
    ;

    create index concurrently recdate on reglog (to_recdate(rectime));
    
另一种思路, 我们也可以创建视图
    
    create or replace view v_reglog as select *, to_recdate(rectime) as recdate from reglog;
    
## JSON等数据类型的支持

在描述业务对象时, 存储的数据经常是稀疏的, 导致绝大部分列数据是空的; 另一方面, 对象属性也是经常变化的. 因此在设计表的时候, 我们索性就用text字段存储json格式的属性.
但是在提取数据的时候, 我们不得不去遍历解析, 才能拿到我们感兴趣的值.

PostgreSQL支持json类型, 还可以根据json字段加索引. 这就很方便我们根据某种属性筛选数据了. 分分钟把 PostgreSQL 当作无范式数据库来使用.

    create table user_info (
        user_id serial,
        info jsonb
    );

    -- 可以根据需要创建函数索引
    create index idx_user_age on user_info (cast(info->>'age' as integer));
    
<!--
    insert into user_info (info) values 
    ('{"username": "alice", "age": 18, "vip": false}'),
    ('{"username": "bob", "age": 20, "vip": true, "played_games": ["qs"]}'),
    ('{"username": "charlie", "play_games": ["ddt", "qs"]}')
    ;
-->
    
    -- 获取json字段
    select info->'username' from user_info;
    
    -- 条件过滤
    select info->'username' as username from user_info where cast(info->>'vip' as boolean) = true;
    select info->'username' as username from user_info where cast(info->>'age' as integer) > 18;

## 更好的执行优化

*TODO*

## 分析函数支持 (Analytical Functions)

分析函数, 在有些场合时非常有用的, 避免了冗余的SQL语句以及多次查询.

- Rollups 
    - 统计每个游戏的最高充值玩家
    - 每个玩家的最近一次登陆记录
- Cubes 快速统计出各个维度组合的数据

当然, 在Hive里面也支持这些函数, 可见使用需求还是非常多的.

    create table paylog (
        time timestamp,
        game char(10),
        username char(10),
        amount numeric(10, 2)
    );

<!--
    insert into paylog values 
    ('2014-01-01 00:00:00', 'ddt', 'a', 10.03),
    ('2014-01-01 00:00:01', 'ddt', 'b', 10),
    ('2014-01-01 00:00:02', 'ddt', 'a', 20),
    ('2014-01-01 00:00:03', 'qs', 'c', 100.3),
    ('2014-01-01 00:00:04', 'qs', 'b', 10)
    ;
-->

    select
        game,
        username,
        sum(amount) as total
    from
        paylog
    group by cube(game, username)
    ;

    select
        game,
        username,
        total
    from
    (
        select
            row_number() over (partition by game order by total desc) as rn,
            game,
            username,
            total
        from
        (
            select 
                game, 
                username, 
                sum(amount) as total
            from paylog
            group by game, username
        ) a
    ) b
    where rn <= 1
    ;

    


## 杂项

### 对SQL标准的更加严格的支持

举个例子, PostgreSQL必须要求`insert into <table>`的写法, 而绝大多数数据库实现(包括MySQL)则允许`insert <table>`的写法.

### 默认区分大小写. 

这点在使用MySQL, 尤其对字符串做distinct操作的时候需要特别注意, 因为默认排序规则(collation)是**不区分大小写的**. 

在MySQL中, 为了避免这个问题, 可以在建表的时候指定:

    create table t (name char(10)) default charset = 'utf8mb4' collate 'utf8mb4_bin';
    
这样在字符串比较是进行的是简单的二进制的比较, 速度自然更快. 至于非英文字符的排序顺序, who cares!
注意这里使用的utf8mb4, 而不是常见的utf8, 因为MySQL的utf8字符集只能支持最多3个字节的编码 (单单就考虑中文情况时, 不会有四个字节的情况), 见<https://dev.mysql.com/doc/refman/5.6/en/charset-unicode-utf8mb4.html>.

### 对写入数据更加严格的检查

对于非法的写入会报错, 而不是像MySQL, 在默认情况下, 将无效数据写入后, 给个WARNING. 个人偏好严格的检查, 在MySQL链接时, 可以通过`SET SESSION sql_mode='TRADITIONAL'`, 开启"严格"模式.

比如说数据截断, 无效数据等.

### 多进程架构

不能孰优孰劣, 不过这个是和MySQL多线程架构是个非常大的区别. 这里我想探讨一下数据库连接的问题.

PostgreSQL, 在每次链接时, 由master进程创建出一个work进程来负责查询请求. 

MySQL每次链接由一个线程负责, 并且内置了线程池的设定 (<http://dev.mysql.com/doc/refman/5.7/en/connection-threads.html>), 数目可以通过`thread_cache_size`设定. 不过这里只是服务器端线程的复用 (thread pool), 为了降低链接过程的开销, 还是需要在客户端部署连接池(connection pool)的.

对于web应用来说, 连接数可能会非常大, 每次链接的逻辑会比较简单, 这个时候创建链接的开销就必须考虑了.

另外, MySQL有商用的thread-pool-plugin可选择. 在(未来的)MySQL 6.0, 以及MariaDB中, 会有 pool-of-threads 的实现, 也就是服务端的线程池处理所有链接的请求.

### DDL的事务支持

这个很有用, 在版本更新改表结构时, 可以稍稍放松一些了哈

### 总结

PostgreSQL提供了非常丰富的功能, 让我等主要用MySQL的人开了眼. 
给我的感觉, 对于标准的更好的支持, 更加严格的约束, 更多的内置功能可以放在数据库端实现, 有助于帮助我们构建更加可靠严肃的数据库应用.

### 参考

- <http://www.wikivs.com/wiki/MySQL_vs_PostgreSQL>

### 安装使用备忘

- <http://www.PostgreSQL.org/download/linux/redhat/>
- <https://www.postgresql.org/download/linux/ubuntu/>

```
    # 初始化数据库, 必须以postgres运行
    sudo mkdir -p /database/pgsql/
    sudo chown postgres /database/pgsql/
    sudo su postgres
    # 解决当前/root目录postgres没有权限
    cd ~ 
    # 初始化数据库, 默认编码, 并默认要求密码登录
    /usr/pgsql-9.4/bin/initdb -D /database/pgsql/data -E UTF8 -A md5 -W

    # 允许外网访问
    # 1. 编辑配置文件
    vim /database/pgsql/data/PostgreSQL.conf
    listen_addresses = '*'
    # 2. 编辑host based configuration文件
    vim /database/pgsql/data/pg_hba.conf
    # 添加如下规则到最前面, 这样我们从任何机器都可以通过密码访问数据库
    host    all            all             0.0.0.0/0            md5

    # 启动服务
    su postgres -c '/usr/pgsql-9.4/bin/pg_ctl -D /database/pgsql/data -l /database/pgsql/logfile start'
    # 关闭服务
    kill -INT $(head -1 /database/pgsql/data/postmaster.pid)

    # superuser登陆
    psql --username=postgres

    # 建库, 给权限
    create database test;
    create user tester with password 'tester_password';
    grant all privileges on database test to tester;
    # 之后就可以普通用户登入了
    psql 

    # 改密码
    \password [role]
```

### 和mysql常用命令翻译表

    # 命令行帮助
    # \? or help;
    \?
    # show databases;
    \l
    # show tables;
    \d
    # use db;
    \c db;
    # desc tbl;
    \d tbl;
    # help command
    \h command
