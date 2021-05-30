---
title: Kafka介绍及RabbitMQ比较
---

# 服务架构

装逼之问, Kafka性能为什么如此优秀? 
- 基于日志文件, 顺序读写 O(1) vs O(log n)
- 充分利用操作系统的读写内存页缓存
- sendfile, zero-copy, 减少用户态切换, 直接socket缓冲区写文件, 数据零拷贝.

概念

![](https://Kafka.apache.org/24/images/log_anatomy.png)

- topic
- partition
- offset
- message
    - timestamp
    - key
    - value
    - headers
- broker 节点
- zookeeper
    - broker
    - topic
    - partition
    - consumer group instance
- replication
    - leader / follower 冗余
- 数据淘汰机制
    - 基于时间
    - 基于日志大小

# 写入

- 跟据key决定具体写入partition
- 批量写入
- 写时数据压缩
- 基于分区的写入横向扩展

# 消费

- 基于offset的手动消费
- Consumer Group / 消费组

![](https://Kafka.apache.org/24/images/consumer-groups.png)

消费组offset管理

- `__consumer_offsets`
  - log compaction by key
- 消费者缓存定期写回, rebalance时写回
  - NOTE: 写回间隔导致的消费监控问题
- 注意消费事务问题
- 保证每条消息至少处理一次, 最好保证消费幂等性

消费延迟计算:

- 基于offset统计: 不同消费速率差别很大, 不能反映真实延迟
- 基于消息时间戳
  - 需要写入时配置支持

# Thoughts: 数据读写接口设计

**面向单条消息设计接口, 内部实现通过批量提交优化性能**

```
type Worker interface {
    func Handle(...) error
    func Flush() error
}
```

# Kafka vs RabbitMQ

Kafka基于磁盘日志的消息代理, pull模式消费数据; RabbitMQ主要基于内存, push模式消费.

生产者/消费者分离, 写入者不用管消费者.
慢消费者不会严重影响Kafka自身服务稳定性.
可随时重放历史数据.

Kafka按消息顺序处理, RabbitMQ单个消息处理确认:

- Kafka最大并行消费者数受分区数限制. MQ则无限制.
- Kafka批处理优化消息处理的吞吐量. MQ注重单条消息的入队列到完成耗时.
- 顺序性缺点: 单消息处理延迟严重影响整体消费速率. 例子: 视频素材处理.
- 顺序性好处: 利用消费顺序性+合理分区键值做事务处理保证.

恰好一次处理 vs 至少处理一次语义.

Kafka可以利用日志压缩功能做数据去重, 当作数据存储, 对于数据堆积且只需要处理最近一次消息的场景有用.

RabbitMQ (AMQP协议) - 本质是异步的RPC.

# Reference

- <https://kafka.apache.org/documentation/#design>
- 
