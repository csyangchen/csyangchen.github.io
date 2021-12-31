---
title: 缓存优化
tags: golang
---

之前也记录过[类似]({% post_url 2017-05-27-config-cache %})的主题, 这里主要说一下实现层面的考量.

# 0 理想情况

所有数据内存中加载, 并被合理的索引. 只要不涉及到外部查询, 请求延迟都非常好控住.

# 1 被动缓存封装

最初我们将需要外部加载, 基于SQL语句的查询封装了一层:

    type Selector interface {
        Select(ctx context.Context, dst interface{}, query string, args ...interface{}) bool
    }

说明: 代码例子图简单, 不含错误处理签名, 下同.

dst一定是个引用对象, 通过反射等方式将值填充进去.
返回布尔值, 用于表示数据是否存在.
这点很重要, 否则调用者需要通过尽心设计传入的dst来判定是否找到数据.

数据库查询基于[sqlx](https://github.com/jmoiron/sqlx)实现.

对于业务调用的要求是`query`尽量是可枚举的, 这样在数据库查询的实现上可以做一些类似prepared statment的查询优化手段.
以及方便针对每个query注册自定义的实现方式.

另外, 基于Redis缓存, 实现一个带缓存逻辑的Selector

    type ByteCache interface {
    	Get(k string) ([]byte, bool)
    	Set(k string, b []byte, ttl time.Duration)
    }

    type CacheSelector struct {
        selector Selector
        cache ByteCache
    }

    func (cs *CacheSelector) Select(ctx context.Context, dst interface{}, query string, args ...interface{}) bool {
        // ...
        ck := CacheKey(query, args...)
        b, found := cs.cache.Get(cs)
        // ...
        if found {
            // 用空做不命中缓存
            if len(b) == nil {
                return false, nill
            }
            unmarshal(b, dst)
            return true
        }

        // 数据库查询
        found = cs.selector.Select(ctx, dst, query, args...)

        // 缓存
        if found {
            b = marshal(dst)
        } else {
            b = nil
        }
        cs.cache.Set(ck, b, ttl)
    }

上述方式, 尽量支持到多种序列化方式, 比如说可以提供一个默认的json/msgpack的实现, 或者由dst实现某种接口以优化序列化性能和缓存数据大小.

    type Marshaler interface {
        Marshal() ([]byte, error)
    }

    type Unmarshaler interface {
        Unmarshal([]byte) error
    }

`ByteCache` 设计上保持简单, 只和`[]byte`打交道.
因为基于`interface{}`的缓存实现, 内存控制手段有限, 也不方便和基于对象反射的`Selector`组合.

缓存接口实现可以进一步发展, 如L2基于redis的公共缓存+L1基于`[]byte`的该实例内部内存缓存. 从调用者来说, 无需关心其数据来自何处.

    type LevelCache struct {
        l1 ByteCache
        l2 ByteCache
    }

    func (c *LevelCache) Get(k string) ([]byte, bool) {
        if b, ok := c.l1.Get(k); ok {
            return b, ok
        }
        if b, ok := c.l2.Get(k); ok {
            c.l1.Set(k, b)
            return b, ok
        }
        return nil, false
    }

注意为了保持`Selector`接口的简洁性, 缓存超时时间等控制参数并没有在接口中体现出来.
简单做可以通过全局配置决定; 或者ctx传递进来, 从而细化缓存生命周期管理.

默认方法设计, 接口额签名首位都用`context`, 方便控制超时, 以及通过`context.WithValue`传参, 便于在不改签名的方式下实现各种功能控制.

# 2 主动缓存

上述的被动缓存机制, 即便内存做了缓存, 由于始终存在序列化的开销, 导致性能存在瓶颈.
且涉及到被动触发查询, 不太可控, 有可能造成惊群.

当然最糟糕的的问题是未命中缓存所带来的额外开销.
假设我们1w个广告, 3k个渠道, 然而只有一个广告对一个渠道开了某个参数, 在被动缓存的方式下, 会最多存储1w*3k=3kw个不命中缓存标记, 可怕!

主动缓存, 思路是将所有数据主动定期加载.

    type Cache interface {
        Get(ctx context.Context, k interface{}) (interface{}, bool)
    }

    type Loader func() map[interface{}]interface{}

    type Memcache struct {
        mu sync.RWMutex
        cacheByQuery map[string]Cache
        loaderByQuery map[string]Loader
    }

    func mc (*Memcache) Select(ctx context.Context, query string, k interface{}) (interface{}, bool) {
        mc.mu.RLock()
        cache := mc.cacheByQuery[query]
        mc.mu.RUnlock()
        return cache.Get(ctx, k)
    }

    // 触发缓存全部重新加载
    func (mc *Memcache) Reload() {
        cacheByQuery := make(map[string]Cache)
        for query, loader := range mc.loaderByQuery {
            cacheByQuery[query] = newCache(loader())
        }
        mc.mu.Lock()
        mc.cacheByQuery = cacheByQuery
        mc.mu.Unlock()
    }

不幸的是, 为了避免序列化开销, 以及主动缓存Cache接口的限制, 这里没有办法实现类似Selector的接口 (dst需要由用户准备好传进来).

键值参数`k`不用`...interface{}`的原因: `[]interface{}` 本身不能比较;
也不采用类似序列化成string的方式, 因为会有性能问题 (我们本身目的就在极力避免格式序列化对么).
所以, 对于调用者一个不方便的一点是, 对于超过一个参数的键值查询, 需要自己构建结构体.

重新加载的时候通过原子性的换掉`mc.cacheByQuery`来减少锁粒度, 当然缺点是对于内存的高要求.
也可以每重新加载一项的时候就将对应的`mc.cacheByQuery[query]`换掉.

注意这里读写锁是必须的, 否则会触发运行时panic, 不要心存侥幸.

# 3 主动缓存读锁优化

实际压测过程中, 发现针对热点查询的主动缓存仍不能满足我们需求. profile发现绝大部分消耗在了`mc.mu`读锁获取上.

我们的服务是, 一个请求, 有可能需要筛选上万的广告, 每个广告筛选涉及多个过滤逻辑, 以及各种配置查询.
即便全部主动缓存住了, 读写锁的频率也是非常高的.

思路是将一个请求周期里面涉及到读锁的查询拿出来, 做到每个请求线程是无锁运行的.

    func (mc *Memcache) SelectAll(query string) Cache {
        mc.mu.RLock()
        defer mc.mu.RUnlock()
        return mc.cacheByQuery[query]
    }

Cache本身实现要求无锁, 例如最简单的方式:

    type mapCache struct {
        kv map[interface{}]interface{}
    }

查询出来并不触发数据拷贝操作.

并将该结果通过ctx传递:

    func WithContext(ctx context.Context, query) context.Context {
        return context.WithValue(ctx, query, mc.SelectAll(query))
    }

    func Select(ctx context.Context, query string, k interface{}) {
        if cache, ok := ctx.Value(query).(Cache); ok {
            return cache.Get(ctx, k)
        }
        return mc.Select(ctx, query, k)
    }

更进一步, 可以懒加载的方式, 减少不会触发的查询数据加载.
只在第一次真正查询的时候再执行`mc.SelectAll`操作, 减少一次读锁获取.
