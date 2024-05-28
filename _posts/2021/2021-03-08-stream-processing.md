---
title: 流计算调研
---

数据处理之5V: Volume / Velocity / Variety / Veracity / Value

对比：批处理 / Batch Processing

Latency vs Throughput vs Correctness 权衡

实时计算业务场景: 一切需要更实时看到数据的业务

# 概念

## 流表二元论

> 阴极阳生, 阳极阴生

- 流 / "阴" / **Stream**
    - log / immutable / 日志存储 / 事件 / 贴源数据层 / 优化写
- 表 / "阳" / **Table**
    - (materialized) view / mutable / KV存储 / 状态 / 应用数据层 / 优化读
- 关系 / "气"
    - 流 -> 流: 变换 / 关联
    - 流 -> 表: 聚合操作
    - 表 -> 流
      - scan / SELECT
      - CDC
    - 表 -> (流) -> 表
- 流 = 时间 + 表/关系
    - 流 = 表 微分 时间
    - 表 = 流 积分 时间

## 算子 / Operators / Transformation

- (stateless) 单行变换: 流 -> 流
    - map
    - explodes / flatMap / SQL行变列或JOIN操作
    - filter / WHERE / HAVING 过滤 / 截流
    - JOIN / UNION / 打宽 / 汇流
    - keyBy / GROUP BY / 分流
- (stateful) 多行聚合: 流 -> 表
    - reduce: <T, T> -> T
    - aggregation: <IN, ACC> -> OUT
    - window 开窗 / 上下文计算
- ORDER BY LIMIT 针对表的算子
  - 流只能 ORDER BY 时间 DESC
- operator chaining
    - 每个算子翻译成一个MR任务开销巨大, "短路"算子, "下推"算子, 优化计算性能
    - SQL: Query Plan Optimization

## 计算框架

这里流/批计算引擎共性

- 源 / Source / Spout / Producer / 上游 / 入 / ingress / ... 从哪儿来?
- 渊 / Sink / Bolt / Consumer / 下游 / 出 / egress / ... 到哪儿去?
  - 同时产生新的流 / 换乘站
  - 不产生新的流 / 终点站
- 算子: 具体业务逻辑实现
- 任务拓扑 / Job Topology / DAG
- 分治 / shuffle / grouping / distribute by / partition by / keyBy
  - Job -> Tasks
  - 计算的水平拓展能力
- 调度器 / Scheduler
- Connectors / Plugins / Executor / Runner
  - 对各种渊/源插件化支持
  - 算子/调度也可以有不同实现

**最要紧在于提炼核心计算模型/接口, 具体实现可以不断演化!**

## 时间窗口 / Window

理解时间
- event time vs processing time
- late arrival: out-of-order vs monotonous
- watermark ~ 计算延迟
  - Latency vs Completeness / 尽快拿到结果 vs 尽可能拿到正确的结果
- late event firing: 触发重算, 补偿正确性
- 允许最大数据延迟 = watermark + allowed lateness
- 对比现在我们定期任务: ut(更新时间戳)找dt(业务时间窗口)逻辑

*画图示意*

Window / 时间窗口: 按照时间将消息流切成固定窗口, 从而进行有意义的计算(成表)
- Tumbling
- Sliding (Hop): size + slide
- Session
  - Dynamic Session
- 其他开窗操作: 基于消息数 / 缓存数据大小 ~ 微批量

## 状态管理 / 可靠性

消费语义

- ~~at-most-once~~
- at-least-once / 下游逻辑需要幂等
- exactly-once
- end-2-end (transactional) extactly-once

State
- 计算所需状态空间大小: state + event -> new state
- 最大: 记录窗口内所有事件
- 问题:
    - PV / 访问次数
    - UV / 访问人数
    - Top-K / 访问次数最多的人
    - 访问时间间隔分布
- 前提: 允许后至事件, 但是不允许错误事件撤回

State Snapshot / 状态快照
- checkpoint / savepoint: 类比游戏自动存档/手动存档
- 避免重新开始的开销
- 类比我们批量计算的快照+日志计算逻辑

依赖源的replay特性来重算, 从而实现可靠性

# Flink相关

- DataStream API : 流操作
- ~~DataSet API : 表操作~~
- Table API (DSL in code)
- Flink SQL

*看DEMO*

# 一些历史/相关产品

- Storm
  - Lambda架构 (λ)
    - Batch Layer (for correctness)
    - Streaming Layer (for speed)
    - Serving Layer (for unified API)
  - 实时计算相比批处理: 不精确/不可靠
  - 业务报表T+1数据模式: 隔日做全量报表 / 当日报表数据简单做
  - 问题：相同逻辑需要做两套
- Kafka: 可重放/顺序消费保障
  - 解耦/读写优化/扩容/数据演化友好/容错/...
  - Kappa架构 (κ): Kafka as database
  - Kafka Streams / KSQL / Samza / ... 完全基于Kafka的流计算 
- Spark -> Spark Streaming (strong consistency, micro-batch, event-time window)
  - micro-batching 本质面向一批消息计算的
  - 单消息处理模型 vs 微批量: 实时性, 一批数据的消费事务问题
  - 后续版本有计划改善: structured streaming / continuous streaming
- Flink: 乱序消息处理 + 状态快照
  - 19年初$100m收购了ververica公司, 整合到阿里云提供Flink实时计算服务
  - 阿里分支Blink, 希望后续逐步合并到Flink
- [Dataflow](https://research.google/pubs/pub43864/) and Apache Beam
  - 流计算范式, 而非具体实现

# 趋势

- SQL化, 简化开发工作
- Python SDK化 (for ML ???)
- 流批一体: 本质是一样的, 开窗粒度区别

# References

- <https://www.oreilly.com/library/view/streaming-systems/9781491983867/>
- <https://martin.kleppmann.com/2016/05/24/making-sense-of-stream-processing.html>
- <https://www.linkedin.com/pulse/spark-streaming-vs-flink-storm-kafka-streams-samza-choose-prakash>
- <http://lambda-architecture.net/>
- <https://www.oreilly.com/radar/questioning-the-lambda-architecture/>
- <https://www.confluent.io/blog/introducing-kafka-streams-stream-processing-made-simple/>
- [The Dataflow Model](https://research.google/pubs/pub43864/)
- [One SQL to Rule Them All: An Efficient and Syntactically Idiomatic Approach to Management of Streams and Tables](https://arxiv.org/pdf/1905.12133.pdf)
