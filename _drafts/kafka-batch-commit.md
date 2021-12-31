---
title: kafka事务消费
tags: kafka, golang
---

消费组

消费程序

如何屏蔽kafka和具体消费逻辑

如何屏蔽主动提交

谁负责主动提交: 消费框架? 消费逻辑本身?

消费成功, kafka提交offset失败, 如何是好

每个partition层面控制, 消费实际逻辑是一个topic的所有parition, 甚至多个topic来的;
批量提交parition的offset失败, 如何是好.

前提: kafka提交offset不会失败.

kafka消费组的逻辑:

每个topic作为一个组, 有新的消费者加入时触发分区的重新分配.

TODO 人工增加分区的时候会触发重新分配么?

删除分区的情况.

消费者必须知晓分区.

提交事务.

consumer.offsets.commitinterval=-1

一直不主动提交, 导致kafka层面监控延迟很高

# Reference

- https://kafka.apache.org/documentation/
