-- <!--
drop database if exists test;
create database test;
use test;
-->

-- # [nested data structure]<https://clickhouse.yandex/docs/en/data_types/nested_data_structures/nested/>
-- 很多业务场景需要我们存储数组类的信息, 以供事后查询分析. 如各种请求的内容, 通常是请求码加上数据列表的形式. 可以通过nested方式实现方便的数据留存和分析.

create table request_log
(
    ts   DateTime,
    aid  Int64,
    code Int32,
    ads Nested(oid Int64, ader_id Int32),
    dt   Date default toDate(ts)
) engine = MergeTree partition by dt order by (aid, ts)
;

-- 写入的时候每个字段当作数组处理
insert into request_log
values (now(), 1, 0, [100, 200], [10, 20], today()),
       (now(), 2, 0, [100], [10], today());

-- 展开统计
select aid, ader_id, uniq(oid)
from (
      select distinct aid, ad.ader_id as ader_id, ad.oid as oid
      from request_log
               array join ads as ad
      where code = 0
         )
group by aid, ader_id
;


create table goods_log
(
    ts    DateTime,
    id   Int32,
    cnt   Int32 comment '库存',
    price Float32,
    tags  Array(String),
    dt    Date default toDate(ts)
) engine = MergeTree() partition by (dt) order by (id, ts)
;

-- 利用 system.numbers 生成随机测试数据
insert into goods_log (ts, id, cnt, price)
select now() + number % 3600,
       rand() % 10,
       toInt32(100 * (1 + cos(toInt64(now() + number % 3600)))),
       rand() % 100 / 10
from (select number from system.numbers limit 100);

-- 虽然暂时不支持window, 但是有类似的上下文计算支持
select any(ts) as first_seen, anyLast(ts) as last_seen, sum(sales) as sales, round(sum(income)) as income
from (
select ts, cnt, greatest(0, runningDifference(cnt)) as sales, price, sales * price as income
from goods_log
where id = 1
order by ts
)
;

-- 利用array相关函数一次性统计全部商品销量
-- NOTE array相关计算比较耗内存, 不适合大数据量计算
select id, sum(tupleElement(sp, 1)) as sales, round(sum(tupleElement(sp, 1) * tupleElement(sp, 2))) as income
from (
      select id,
             arrayZip(arrayDifference(groupArray(cnt)), groupArray(price)) as sp
      from (select * from goods_log order by ts)
      group by id
         )
array join sp
where tupleElement(sp, 1) > 0
group by id
order by sales desc
;


-- # 风骚的WITH用法
-- 虽然没有window函数, 但是很多时候也够了
-- formatReadableSize 良心函数
with (select sum(bytes) from system.parts where active) as total_disk_usage
select database,
       table,
       formatReadableSize(sum(bytes))                                         as size,
       concat(toString(round((sum(bytes) / total_disk_usage) * 100, 2)), '%') AS ratio
from system.parts
group by database, table
order by sum(bytes) desc
;


create table nginx_log
(
    ts         DateTime,
    upstream   String,
    path       String,
    query      String,
    method     String,
    ip         String,
    status     Int16,
    latency_ms Int32,
    dt         Date default toDate(ts)
) engine = MergeTree() partition by (dt) order by (upstream, ts);

insert into nginx_log (ts, upstream, method, ip, status, latency_ms)
select now() + number % 86400,
       ['a', 'b', 'c'][1 + rand() % 3],
       'GET',
       IPv4NumToString(rand()),
       200,
       log10(rand() % 1000)
from (select number from system.numbers limit 100)
;

-- 可以动态添加字段, 调整数据结构类型
alter table nginx_log modify column method LowCardinality(String);

-- 5分钟P95分位数统计, 结合redash/grafana做监控
select toStartOfFiveMinute(ts) as dt, upstream, quantile(0.95)(latency_ms) as latency_ms_p95
from nginx_log
group by dt, upstream
;


-- # 分区管理
-- https://clickhouse.yandex/docs/en/query_language/alter/#alter_manipulations-with-partitions
-- https://clickhouse.yandex/docs/en/operations/table_engines/custom_partitioning_key/
-- 注意分区不能太多, 否则写入的时候有可能触发到[max_partitions_per_insert_block](https://clickhouse.yandex/docs/en/operations/settings/query_complexity/#max-partitions-per-insert-block) 限制
-- 一般按天分区足够, 业务查询字段通过order by来解决
-- 分区和上有数据重跑逻辑对应, 如kafka topic等

-- 历史数据管理
-- detach 卸下来的分区可以通过拷贝到OSS/S3的挂载盘来实现备份和恢复.

-- [Database Engine: Mysql](https://clickhouse.yandex/docs/en/database_engines/mysql/)
-- Clickhouse支持MySQL driver, 可以通过创建MySQL存储的表/库, 实现Clickhouse查询写入MySQL, 或者关联MySQL属性表的业务需求.
-- 在真正查询/写入的时候才连MySQL, 建表的时候并不判断是否可以连上.

-- 准备CH日志表
drop table if exists ch_log;
create table ch_log
(
    ts  DateTime,
    uid Int32
) engine = MergeTree() partition by (toDate(ts)) order by (ts);
insert into ch_log
select now() + number, 1 + rand() % 3
from (select number from system.numbers limit 300)
;

drop database if exists mysql;
create database mysql engine = MySQL('mysql:3306', 'test', 'root', 'pass');

-- MySQL数据库自动全发现
show tables from mysql;

-- 只支持select/insert操作
-- MySQL表的not null字段必须有, 即便设置了默认值也不行
-- NOTE: 写入不能有主键冲突
insert into mysql.report (dt, uid, cnt, ct, ut)
values (now(), 1, 1, now(), now());
select *
from mysql.report;

-- [Table Engine: MySQL](https://clickhouse.yandex/docs/en/operations/table_engines/mysql/)
-- 为了支持去重更新, 可重复执行逻辑
create table mysql_report
(
    dt   Date,
    uid  Int32,
    name String,
    cnt  Int32
) engine = MySQL('mysql:3306', 'test', 'report', 'root', 'pass', 0, 'update cnt=values(cnt), name=values(name)');

-- CH汇总后写入MS
insert into mysql_report (dt, uid, cnt)
select toStartOfHour(ts) as dt, uid, count(1) as cnt
from ch_log
group by dt, uid
;

-- 关联MS属性表后再写入
insert into mysql_report (dt, uid, name, cnt)
select dt, uid, name, cnt
from (select toStartOfHour(ts) as dt, uid, count(1) as cnt from ch_log group by dt, uid) as t join mysql.users
on t.uid=users.uid
;


-- [SummingMergeTree](https://clickhouse.yandex/docs/en/operations/table_engines/summingmergetree/)
-- CH的天统计表, 自动汇总
-- TODO 更复杂的merge逻辑
drop table if exists report;
CREATE TABLE report
(
    dt    Date,
    uid   Int32,
    total UInt64
) ENGINE = SummingMergeTree(dt, (dt, uid), 8192);

insert into report
select toStartOfHour(ts) as dt, uid, count(1)
from ch_log
group by dt, uid;

insert into report
select toStartOfHour(ts) as dt, uid, count(1)
from ch_log
group by dt, uid;
select *
from report;

-- optimize 手动触发merge
optimize table report;
select *
from report;
