---
title: 广告投放系统数据查询的套路
---

广告投放系统, 从逻辑上来说不复杂, 无非是根据请求, 根据业务逻辑, 查询配置信息, 决定返回投放的广告信息, 诸如此类.

投放系统业务层面逻辑相对不算复杂, 主要的挑战来自于大流量情况下的请求处理能力.
如何"高效"地查询广告相关数据这一环节, 对于系统承载能力非常重要.
如果每个请求过来, 都需要直接查数据库, 那是最糟糕的情况.
所以一般的套路就是使用缓存机制.

## 被动缓存

Cache Aside Pattern: 即先查缓存, 如果命中, 返回结果; 若否, 查询外部数据并写入缓存.
缓存数据一般不会永久生效, 视业务场景设置一定的失效时间(TTL).

如果业务逻辑不允许"脏读", 则需要在外部数据写入的时候, 将相关缓存记录擦除, MySQL Query Cache 使用的就是这种机制. 一般业务系统做不到主动失效缓存这点, 也可以接受一段时间的脏读.

这种做法优点是实现起来比较简单, 并且热点数据越集中, 流量越高的情况下缓存命中越高, 平均相应时间越快.

要注意的几个问题:

### 避免惊群效应

请求并发度非常高, 并且外部数据查询延迟较高的极端情况下, 需要注意缓存失效导致的"惊群效应"(thundering herd), 请求压力瞬间穿透到后端数据库.

需要有机制保证在缓存失效的时候, 同时穿透到外部数据查询的并发请求数目可控.
具体实现上需要考虑多个请求间的协同问题, 会比较恶心 (分布式锁, 光看名词就问你怕不怕?).

一种解决思路: 在缓存失效时有通知机制, 程序自己重新填充缓存.

另一种解决思路: 查询数据时, 一定概率直接查数据库并触发重新缓存, 以避免缓存被动失效.
注意要控制好频次, 不要用固定概率的方式, 因为这会导致外部数据查询的QPS和流量量级线性相关, 很糟糕. 实现上的几个思路:

- 限流机制, 但是带来了另外额外的维护负担
- 重新触发缓存的概率和TTL剩余时间负相关

### 避免无效数据穿透

很多时候会受到不少无效的请求 (或者换种手法, 查询的数据本身就不存在), 对于无效请求数据, 也要视情况加以缓存, 避免无效请求穿透缓存. 无效数据TTL可以视策略单独设定.

另外也要防范针对无效数据缓存的恶意攻击: 攻击者制造很多无效请求触发无效数据缓存,
影响正常的数据请求缓存处理.

应对的想法: 除了正常的DDos防范机制, 以及实施请求限流策略之外, 在做缓存数据淘汰的时候, 优先淘汰无效缓存记录, 避免无效缓存记录占满缓存内存资源, 确保有效缓存数据还是能被命中的.

## 主动缓存

被动缓存的方式, 实现上比较简单, 问题也不少: 脏读, 不可避免的外部数据查询 (以及由此引发的请求响应延迟不确定性, 在实时性要求比较高的业务场景下不可接受).

被动缓存的效果需要看缓存命中率, 如果太低, 反而是负面效果.

此外, 在请求量级非常大的业务场景下, 即便使用被动缓存, 缓存失效导致的外部数据查询量仍然是不可接受的, 会直接拖垮数据库.

另外, 被动缓存在不命中的时候不确定数据是否有效, 仍需要二次确认机制, 以及用宝贵的缓存资源去缓存无效数据.

如果采用主动缓存的方式, 将所有相关数据加载到缓存系统, 不命中就可以直接判定出局, 查询逻辑处理上更加简单.

### 主动缓存的姿势

数据写入的时候触发缓存写入: 写数据库的通知, 也往缓存里面写一份 (或者在有被动缓存机制的情况下, 先写数据库, 然后删除相关缓存记录).
这要求配置更改的服务也做缓存的逻辑, 耦合太高, 太复杂, 不建议.

基于变更通知的解决方案

- 业务端部分解偶的做法: 配置端更新相关数据时, 不写具体缓存内容, 而是发布更新的数据维度, 触发关心(即订阅)该纬度数据的其他系统去拉取缓存所关心的数据.
    - 订阅机制可以用 redis pub / sub 等
- 基于数据库的方案
    - 基于消费 MySQL bin log 的方案, 要求必须以行模式(row based replication)进行同步, 这个套路有很多相关工具
    - PostgreSQL notify 的机制, 可以把关心的数据查询用视图的方式包装通知过来, 我们 DSP 系统使用了这种方式, 非常爽!

遇到的问题: 在写端更新非常频繁, 或者一次更新量非常大时, 订阅端消费的压力非常大 (这个是我们在DSP上面遇到的问题).
订阅发布模式异步化可以部分解决这个问题, 但是也有消费持续地更不上生产的风险.

另外, 在很多业务场景, 并不需要即刻的数据更新, 一段时间的脏读是可接受的.

以上几种方式都需要引入外部系统支持, 有没有更加简单的方式呢? 有的, 我叫它"UT套路":

数据库表都标记一个最后更新时间时间戳, 程序记录每次读取的时间戳, 定时轮询更新的数据并触发数据重载:

    select * from table where ut > last_sync_time

对于数据库表设计的要求:

- 不允许直接删除数据, 可以用一个字段标记是否生效
- MySQL 允许每个表有最多一个自动更新的时间字段, 建议统一标准为 ut 字段: `ut timestamp not null default current_timestamp() on update current_timestamp()`
- 注意对 更新时间戳字段 ut 加索引
- "UT套路"也适用于上游下游报表数据做增量同步的场合

这种套路适用于数据库表设计比较平整的情况, 例如投放计划信息在一张表里面就记录全了. 对于一开始的数据模型设计的要求较高.

很多系统, 由于历史原因, 或者复杂度的增长, 业务层面的信息需要从多个表复合查询得到, 这个时候就比较麻烦了.

可以考虑用触发器来简化复杂性: 所有和关心维度相关字段的更新, 创建一个触发器, 往另外一个变动表里面来记录变动. 系统通过该变动表重新拉取相关信息.

另外, 触发器模式也可以用来做业务无关的配置变动记录管理.

# 缓存形式

- 程序内存里面自己做缓存机制, 是最高效的手段, 整体请求延迟也可控.
    - 实现时要注意锁的粒度
    - DSP投放系统目前采用此种形式
    - 缺点是重启后全部丢失, 需要冷启动. 可以通过程序停止时dump出全部缓存数据, 启动时重新加载来缓解.
- 使用外部缓存, 如 Redis, 可以做到跨业务服务的缓存共用; 量级大时, 采用集群化的部署, 便于横向扩展.
    - 可以将各个模块解耦, 如缓存刷新服务可以提出来单独做
    - 外部缓存要注意链接池的使用
- 另外也结合需求, 也可以考虑多级缓存的方式 (如内存缓存不命中, 取外部缓存查找, 热点数据内存缓存), 充分利用局部性提升查询性能

好了啰嗦完了, 大家共同探讨, 努力提高姿势水平.

# Reference

- <http://coolshell.cn/articles/17416.html>
- <https://docs.microsoft.com/en-us/azure/architecture/patterns/cache-aside>
- <https://dev.mysql.com/doc/refman/5.7/en/query-cache.html>
- <https://dev.mysql.com/doc/refman/5.7/en/replication-formats.html>
- <https://www.postgresql.org/docs/current/static/sql-notify.html>
- <https://github.com/golang/groupcache>
- <http://engineering.rainchasers.com/cache/memcached/2015/03/10/ttl-cache-thundering-herd.html>
- [大型网站技术架构](https://book.douban.com/subject/25723064/) 比较浅显, 可以作为科普扫盲读物看看
