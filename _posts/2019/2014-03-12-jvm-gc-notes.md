---
title: JVM GC 笔记
tags: java
---

## 什么是GC, 为什么要GC?

内存回收 (Garbage Collection, 简称GC), 一般理解为在不需要在编程人员显式控制下, 自动执行内存申请和释放的程序机制. GC解放了程序开发时内存操作逻辑的负担, 从而提升开发效率; 另一方面, 在一定程度上, 减少内存相关BUG的出现, 如内存越权读写, 内存泄漏等.

Java作为目前一个非常重要的编程语言, 了解其官方虚拟机(HotSpot JVM)执行时的GC机制, 可以帮助我们定位性能问题, 从而通过合理的编程策略和JVM配置, 提高程序性能.

## 基于对象存活时间的GC算法

首先, 关于程序内存使用的一个事实: 绝大多数内存请求用于临时数据处理, 大小较小, 存活期也很短.
基于这样一个事实, JVM采用了基于对象存活时间的GC算法, 将短生对象和常生对象分成连个池子单独处理. 分别称作新生代和老生代.
此外还单独有存放加载的类代码等的永生代, 永生代不参与GC.

- 新生代的内存分配策略是非常快的, 直接分配内存空间.
- 老生代的内存分配, 则可能会涉及到已有内存对象的整理操作.
- 当一个对象在新生代存活了足够多的GC次数后, 会被拷贝到老生代.
- 新生代又分为两个部分: "伊甸园"(Eden)和两个"候选区"(Survivor Spaces), 新的内存请求直接在伊甸园完成, 此处空间满时会触发minor GC, 此时会把伊甸园中存活的对象请到当前空闲的候选区To中. 而之前已被驱赶到候选区From的对象, 会经过考察, 如果已满足升级至老生代资格, 则会被请到老生代中享受剩余的时光; 如果不满足资格, 则被驱赶到候选区To中. 此时候选区From已经清空, 两个候选区角色互换, 等待下一轮的minor GC.
- 慢慢的, 当老生代内存也用满时, 则会触发full GC. 这是程序所应该尽量避免的, 因为一般来说, full GC所需检视的对象较多, 用时也较长, 从而导致潜在的程序响应的问题. full GC的一般思路即检视无用的对象, 内存整理去碎片化, 将剩余存活对象打包到一起(compaction), 以留出整块的可用空间. 具体的full GC策略及涉及到的引擎在这里不再细数

## 观察GC过程及调节参数

可以通过设定如下环境变量, 来告诉JVM记录GC的详细信息:

    export SERVER_GC_OPTS="-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:<FILE-PATH>

也可通过程序启动时加jvm相关配置参数来记录GC信息.

启用后, 会看到如下的日志记录:

    [GC [DefNew: 64575K->959K(64576K), 0.0457646 secs] 196016K->133633K(261184K), 0.0459067 secs]
    // 含义:
    // [GC [新生代GC信息] GC前对象大小->GC后对象大小(可用内存大小) GC时间]

## 常用配置参数

配置内存大小

-Xmx 最大预留堆空间大小
-Xms 最大预留堆空间大小

控制参数:

- MinHeapFreeRatio/MaxHeapFreeRatio 最大/最小堆利用率, 用于触发堆空间的动态增减
- NewSize 新生堆初始大小
- NewRatio 老生堆和新生堆比例
- SurvivorRatio 在minor GC中, 伊甸园和每个候选区的比例

GC引擎(GC collector)的选择:

- -XX:+UseSerialGC 没啥好说的, 最基本的GC引擎
- -XX:+UseParallelGC 又称作throughput collector, 并发执行新生代GC
- -XX:+UseParallelOldGC 改进了老生代GC, 对老生代内存分片区进行并发GC
- -XX:ParallelGCThreads=<N> 并发执行GC的线程数目
- -XX:+UseConcMarkSweepGC 又称作low-latency collector, 老生代GC和应用程序并发执行, 不做内存整理
-  此外还有最新的G1引擎(Garbage-First Collector)可供选择, 它在jvm1.7u4后为默认引擎

### GC调节策略

GC算法是一个策略问题, 主要关注的点(按照优先级从高到低):

1. 响应速度(即减少GC时间)
2. GC效率
3. 内存利用率

在JVM中, 我们可以通过设定关心的指标, 来指导JVM的具体GC的策略:

- -XX:MaxGCPauseMillis=nnn, 要求每次单次GC时间不超过nnn毫秒, 从而保证程序的响应速度
- -XX:GCTimeRatio=nnn 要求GC时间占比要不超过 1 / (1 + nnn), 通过减少GC时间占比从而提高吞吐量

## JVM内存相关检视工具

- jmap: jvm内存检视和dump工具
- jhat: 分析dump出来的文件; dump文件也可以通过-XX:+HeapDumpOnOutOfMemoryError参数, 在抛OutOfMemoryError异常时生成
- jconcolse: 图形化的检视工具
- jstat: JVM 监测工具

## 参考

- [J2SE 5.0 Performance White Paper](http://www.oracle.com/technetwork/Java/5-136747.html)
- [HotSpot JVM options cheatsheet](http://blog.ragozin.info/2013/11/hotspot-jvm-garbage-collection-options.html)
- [Java HotSpot Garbage Collection](http://www.oracle.com/technetwork/Java/Javase/tech/index-jsp-140228.html)
- [Java SE HotSpot](http://www.oracle.com/technetwork/Java/Javase/tech/hotspot-138757.html)
- [Java SE 6 HotSpot Virtual Machine Garbage Collection Tuning](http://www.oracle.com/technetwork/Java/Javase/gc-tuning-6-140523.html)
- [JVM的GC简介和实例](http://www.searchtb.com/2013/07/jvm-gc-introduction-examples.html)

## 附:

    // jmap检视内存使用情况的实例
   
    > jmap -heap 46106
    Attaching to process ID 46106, please wait...
    Debugger attached successfully.
    Server compiler detected.
    JVM version is 20.8-b03

    using thread-local object allocation.
    Parallel GC with 8 thread(s)

    Heap Configuration:
       MinHeapFreeRatio = 40
       MaxHeapFreeRatio = 70
       MaxHeapSize      = 1073741824 (1024.0MB)
       NewSize          = 1310720 (1.25MB)
       MaxNewSize       = 17592186044415 MB
       OldSize          = 5439488 (5.1875MB)
       NewRatio         = 2
       SurvivorRatio    = 8
       PermSize         = 21757952 (20.75MB)
       MaxPermSize      = 85983232 (82.0MB)

    Heap Usage:
    PS Young Generation
    Eden Space:
       capacity = 352911360 (336.5625MB)
       used     = 145644456 (138.89737701416016MB)
       free     = 207266904 (197.66512298583984MB)
       41.269415640233284% used
    From Space:
       capacity = 2424832 (2.3125MB)
       used     = 327712 (0.312530517578125MB)
       free     = 2097120 (1.999969482421875MB)
       13.514833192567568% used
    To Space:
       capacity = 2228224 (2.125MB)
       used     = 0 (0.0MB)
       free     = 2228224 (2.125MB)
       0.0% used
    PS Old Generation
       capacity = 715849728 (682.6875MB)
       used     = 528781040 (504.28489685058594MB)
       free     = 187068688 (178.40260314941406MB)
       73.86760367673143% used
    PS Perm Generation
       capacity = 68943872 (65.75MB)
       used     = 47600648 (45.39551544189453MB)
       free     = 21343224 (20.35448455810547MB)
       69.04260903710195% used
