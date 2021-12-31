---
title: 超叼的Clickhouse
tags: clickhouse
published: false
---

18年开始在业务上逐步使用了Clickhouse. 小小单机承载了每日10亿量级的点击日志写入, 以及各种姿势的查询.

# 丰富数据结构及函数

- nested data structure
- bitmap



# 外部互联

kafka

相对不够成熟, 数据同步还是尽量从数据库解耦做.

mysql

基本比较稳定, 我们用于一些快速数据同步, 以及一些线上接口的IN子查询.
要格外注意由于类型问题导致筛选条件没有去到MySQL执行的问题. 

MergeEngine

SummingMergeTree / Aggregatingmergetree 需要实时写入并统计场合

ReplacingMergeTree / 用于同步MySQL表

<!-- sed s/--//g clickhouse-rocks/ch.sql -->

# Reference

- <https://clickhouse.tech/docs/en/>
- <https://altinity.com/blog/>