---
title: 频次控制
---

# 频次控制需求

频次控制(rate limit), 在一个后端开发中有许多使用场景

- 为了避免服务过载, 需要对超出服务能力的请求进行throttle
- 为了避免个别客户的暴力行为导致整个服务不可用, 需要根据请求来源进行限制
- 为了合理预留资源, 服务API需要对客户请求量, 按照约定进行限制, 这也和服务计费紧密关联
- 在广告投放领域, 为了保证全天投放, 或者说为了触及最多的用户, 需要对于投放计划进行频次控制, 如: 每日预算需要均匀消耗; 一个投放计划, 对于同一个用户, 每天最多投放3次; 等

频次控制策略可以是叠加的, 在不同时间长度上叠加的, 如, 请求量不能超过5次/秒, 10W次/小时.
每个请求的权重可以不一样, 一般根据请求的数据大小来进行限制, 也可以根据接口的复杂度分开定义.
例如, 写入请求不能超过5次/秒, 写入量不能超过1Mb/秒; 读请求不能超过10次/秒, 读数据量不超过2Mb/秒.

突发请求的支持：
对于一个服务的请求, 其流量特征可能是突发性的, 常见的频次控制会提供一个burst参数.
可以简单理解为一个"贷款额度", 通过透支将来一段时间的容量来满足当前突发的流量请求.
于此相关的, 还有一个容量累积的实现. 区别在于是否可提前"预支".
比如说这个存储服务一段时间一直没有使用, 这段空闲时间的IOPS可以一直累积下来, 直到达到一个最大累积值. AWS的一些磁盘读写服务采用这种策略.

流量塑形 vs 流量调度策略

在预留不足时延迟处理, 使流量分布满足既定的策略, 这种叫做流量塑形(Traffic Shapping).
于此相对应的, 在预留不足时直接拒绝服务, 这种属于流量调度策略(Traffic Police)?

打个不恰当比方, 事故多发路段的车速限速标识, 属于流量塑形; 十字路口的红灯停绿灯行, 属于流量调度.

- 如果限流情况不严重, 延迟处理等待时间较短, 可以延迟处理并返回结果, 从而避免无效请求
- 如果直接返回, 被拒绝服务的客户端可能会不断重试, 给服务接口造成不必要的请求负担, 因此即使限流直接拒绝服务, 服务端也可以等待一段时间后再返回错误, 以降低整体无效请求量

当然, 更好的服务API会在返回结果中给出频次控制相关信息, 以帮助客户端做好请求频次控制, 提高请求的成功率.

# 频次控制算法实现

漏桶算法, 顾名思义, 就是生产者以一定速率"放水", 超过"桶"容量的部分不累计, 消费者消费"桶"中可用容量, 不足时出发限流逻辑.

漏桶算法 (Leaky Bucket) 令牌桶算法 (Token Bucket), 两者类似, 思路都是差不多, 没有必要分得太清楚, 仅仅说一下概念上的区别:

- 漏桶算法: 不支持burstiness, 没有队列的概念, 限流后即拒绝服务
- 令牌桶算法: 支持burstiness, 有队列的概念, 限流后的请求按照先来后到的顺序处理

实现上的注意:

考虑到需要频次控制对象的量级, 主动定时填充漏桶容量, 是不现实的.

一般采用"懒"的方法, 在请求到来时, 读取对应桶上次请求时间戳, 计算当前可用容量, 判断该次请求是否限流.

    func (self bucket) ratelimit(cost):
        self.tokens = self.tokens + rate * (now() - self.last_update_time)
        if self.tokens > burst:
            self.tokens = burst
        tokens = self.tokens - cost
        if tokens < 0:
            return false
        else:
            self.tokens = tokens
            return true

另外在实现的过程中要注意到多线程带来的问题.

从频次控制存储来看, 分为两种策略:

- 程序内部实现, 优势在于速度快, 实现轻量, 缺点是重启后信息丢失, 另外频次相关数据量级可能会非常大, 适用于需要频次控制的对象可控的场景
- 借助外部存储, 服务本身可以做到无状态, 重启不重置频次信息, 多个服务可共享频次信息, 缺点需要和外部存储通讯的开销, 适用于需要在较长时间进行频次控制的需求, 以及频次控制对象不确定的情况

## redis 实现

a. interval 时间内不超过1次
b. interval 时间内不超过n次

对于a场景:

    if EXISTS key:
        return false
    else:
        SETEX key interval 1
        return true

对于b场景, 一个简单的实现:

    cnt = GET key
    if cnt == 0:
        SETEX key interval 1
        return true
    else if cnt < n:
        INCR key
        return true
    else:
        return false

维护一个计数器, 并在第一次累加的时候设置超时时间.

这种实现, 问题在于限流控制不够均匀.
例子: 3次/5秒. 00:00一次请求, 00:05两次请求, 之后计数器超时, 00:06再次请求三次时仍能通过,
那么从00:05 ~ 00:10时间段来看, 没有达到3次/5秒的要求.

怎么办呢? 用 sorted set 结构, score字段计数, member字段需要保证唯一, 如唯一请求ID, 或者用粒度足够细的时间戳也可

    ZREMRANGEBYSCORE key 0 TIME - interval # 删除之前的记录
    cnt = ZCARD key
    if cnt > n:
        return false
    else:
        ZADD key NX 1 TIME
        if cnt == 0:
            EXPIRE key duration

这种方式对于频次控制的力度最为精确, 但要注意其缺点:
依赖于字段唯一性, 这点有时候并不容易达到;
复杂度很高, O(n), 不适用于量级比较大的场景, 如1W次/小时.

如果必须采用这种方案, 为了保证性能, 需要对参数n做上线限制, 频次控制参数上可以做一些折衷, 如将"1W次/小时"翻译为"100次/X秒". 这需要在业务上进行评估.

## redis借助lua脚本实现事务操作

注意到, 上述很多先读后写的操作, 没有实现事物.

redis本身所谓的[事务](https://redis.io/topics/transactions), 也不能根据读取的数据条件执行.
redis支持执行lua脚本, 并且每个lua脚本执行时是独占的, 因此可以采用redis里面执行lua脚本的方式来实现业务上的事务操作.
具体实现不细说, 但有一点注意, 由于独占执行, 需要控制lua脚本的复杂度, 过慢的lua脚本会拖垮整个redis数据库的读写速度.
可以通过redis集群的方式提升并发度, 当然这个不在我们这里讨论的范畴.

## Golang语言实现

不考虑性能问题, 用原生的 buffered channel 实现非常自然.

    type Token struct{}

    ch := make(chan Token, burst)

    // producer
    for range time.Tick(1/rate) {
        select {
        case ch <- Token{}:
            // ok
        default:
            // drop
        }
    }

    // consumer
    select {
    case _ <- ch:
        return true // ok
    default:
        return false // not ok
    }

当然它的问题在于需要频主动去填充 channel, 另外对于ch的频繁独占操作也是潜在的性能瓶颈。

另外Golang也有使用锁方式的实现版本， 例如[这个](https://github.com/golang/time/blob/master/rate/rate.go).

# 一次性读写 以及 先读后写

前面讨论的频次控制, 都是如果不限流直接消费, 然而在广告筛选中, 情况可能不是这样:

在广告筛选阶段, 判定该广告是否已达到频次限制, 若否, 加入广告候选列表, 并在最终广告筛选时更新该广告投放频次信息.

频次控制检查和频次更新中间会有很多的复杂操作, 在并发度较高的时候, 会出现频次控制超出预期的情况.

一个思路: 在频次检查时直接消费, 或者说执行"预定"操作, 在筛选出最终展示广告后, 对于不出价的广告执行取消或者说"回退"操作.
不过这个写开销会比太高, 考虑到满足条件广告的量级.

在实践中, 我们没有这么做, 而是通过限制并发请求数, 来缓解频次控制超标的问题.

# 客户端请求重试的正确姿势

在客户端遇见可重试的错误时, 如网络/服务暂时不可用时, 一般采用指数时间退让的办法, 当达到最大重试次数后再放弃尝试, 返回错误.
多余多个客户端同时请求一个服务的场景, 为了避免同一时刻请求量的爆发导致系统颠簸(thrashing), 需要在退让时间加上一定的随机性.

# 参考资料

- <https://en.wikipedia.org/wiki/Leaky_bucket>
- <https://en.wikipedia.org/wiki/Token_bucket>
- <https://www.quora.com/What-is-the-difference-between-token-bucket-and-leaky-bucket-algorithms>
- <http://nginx.org/en/docs/http/ngx_http_limit_req_module.html> nginx自带的限流模块
- <http://stackoverflow.com/a/668327>
- <https://github.com/golang/go/wiki/RateLimiting>
- <https://github.com/golang/time/blob/master/rate/rate.go>
- <https://godoc.org/?q=rate+limit>
- <https://cloud.google.com/storage/docs/exponential-backoff> 指数退避策略