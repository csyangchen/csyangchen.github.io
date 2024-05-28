---
title: MySQL主从同步和触发器实践一则
tags: mysql
---

## 场景

在做充值数据库同步的时候, 在从库的充值表上加上了INSERT和UPDATE触发器, 用于记录更新的充值记录.
经测试发现从库上只有INSERT触发器执行了, 而UPDATE触发器没有被执行.

## 分析

触发器只有在相关SQL语句被执行的时候才会被触发, 在行同步模式(RBR)下不会被触发, 所以为了保证从库上添加的触发器能够被顺利执行, 我们需要主从同步是通过SBR执行的.

数据库主从是混合模式同步(MIXED), 也就是说默认情况下是基于语句同步的(SBR), 只有在特殊条件下切换成RBR. 因此定位问题是UPDATE的时候同步自动切成了RBR.

看MySQL的文档, 对MIX模式下切换成RBR的几种场景逐一排除.

初步怀疑是AUTO_INCREMENT字段导致的, 测试后发现其实没有影响.

最终从主库执行的语句上下手, 定位到了问题, UPDATE是这样做的:

    UPDATE ... WHERE PayNum=XXX LIMIT 1;

MySQL在MIXED模式下含有LIMIT语句会切成RBR模式同步.

暴露的问题:

- 订单生成的时候PayNum没有能够保证唯一, UPDATE语句为了填这个坑加了一条LIMIT 1限制, 建议做到订单流水号生成唯一.
- 主从三种同步模式机制, 尤其是对于MIXED模式的切换机制了解不够.
- SBR同步坑很多, 尤其是在涉及到主库/从库上有触发器的场景, 很容易造成主从数据不一致, 还是RBR比较安全 :)

## 解决办法

- 这个`LIMIT 1`是当年充值系统写的烂, 订单号居然不是主键, 醉了 (不过, 如何生成订单本身确实也不是简单的问题)!
订单号保证唯一后, UPDATE语句去掉LIMIT
- 主从改成模式SBR同步, 不过想想不靠谱, 为了保证数据的一致性, 最好全部RBR
- 用INSERT/UPDATE触发器来跟踪变动, 想法本身还是比较幼稚, 另外对从库性能有害. 考虑通过解析MySQL的bin-log, 这种在MySQL外部离线方式, 来记录发布变动信息.
相关的有阿里的[canal](https://github.com/alibaba/canal)等开源工具

## 参考

- [MySQL同步模式介绍](http://dev.mysql.com/doc/refman/5.1/en/binary-log-formats.html)
- [MIX 模式介绍](http://dev.mysql.com/doc/refman/5.1/en/binary-log-mixed.html)
- [同步需要注意的问题纵览](http://dev.mysql.com/doc/refman/5.1/en/replication-features.html)
- [同步和AUTO_INCREMENT的关系](http://dev.mysql.com/doc/refman/5.1/en/replication-features-auto-increment.html)
- [同步和LIMIT语句的关系](http://dev.mysql.com/doc/refman/5.1/en/replication-features-limit.html)