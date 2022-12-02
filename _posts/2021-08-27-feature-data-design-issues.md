---
title: 数据需求设计讨论
---

*内部培训讲义精简*

功能需求=数据需求: 任何功能都是数据驱动的.

# 数据字典/链路

业务名词, 基础数据关系定义必须全员充分理解无歧义.

复习: 主体 / 关系 / 单属性(类别) / 多属性(标签) / 固有属性 vs 动态属性 / 指标

# 功能开发流程

四环节

1. **评需求**
   - 及格: 澄清要做啥, 能够给别人讲清楚
   - 进阶: 明白做的价值, 价值点评估, 理解客户使用场景
   - 预见: 预判下一步的需求, 保持方案的灵活性
2. **拆接口:** 按照需求页面原型拆解数据接口
3. **定结构:** 评估每个接口查询依赖的表需要如何摆/组合
4. **做同步:** 涉及数据表调整的, 从上游基础关系表做数据同步逻辑开发维护 

三阶段

1. **做什么** / 需求评审(会)
    - 甲方角色: 把自己当作客户, 这个需求是否合理, 是否有价值, 对产品"售卖"的这个故事是否"买单?
    - 乙方角色: 从实现角度评估判断, 心里对于怎么拆接口/定结构/做同步要有数了, 每个功能的开发难度/成本有基本预期
2. **怎么做** / 技术评审(会)
    - 简单的不需要进一步技术调研类需求, 应该需求评审会后立刻召开
    - 关注工程维护/灵活性
    - 关注非功能要素
    - 评审确认方案能够即刻"外包", 及随便交给任意同学能够理解并独立完成
3. **做咋样** / 效果评估复盘(会)

(会): 尽量不开会, 写清楚文档, 异步离线方式沟通效率更高; 不得不开会, 会议必须有结论, 并记录; 做到过程管理有据可查. 

> 写清楚才代表想清楚, 避免口口相传非物质文化遗产!

# 产品功能基础要素

- 导航 / 信息流 / 用户故事
- 主体/列表/详情
- 搜索
- 筛选
- 时间筛选
- 排序
- 跳转/链接/面包屑
- 导出
- ...

# 主体

- 展示何种信息/字段
- 预见性: 展示类字段最终都可能有搜索/排序/筛选需求
- 有跳转的要注意数据一致性问题, 是否要带上当前时间筛选参数等问题

## 分页

分页/翻页交互尽量砍为下一页/瀑布流, 后端实现统一简化为游标方式, 避免深分页导致的性能问题

技术决策: 数据量少的情况下, 优先整体返回前端分页, 解决性能及数据一致性问题

## 总数

总数超过一定量级后, 从客户使用价值角度是个约数值, 追求总数精准的场景应该总数做成指标, 转榜单需求

## 更新时间

- 正常逻辑: 当前筛选条件下的最后更新时间, 也便于内部排查问题
  - 最后更新时间 = 当前视图下的数据唯一版本 !
  - 和查总一并做: `select count(1) as total, max(modify_time) from source where ...`
- 弱化: 当前筛选时间段的最后更新时间 (当前榜单更新时间, 或者用于推断数据延迟情况)
- 最挫: 当前查询数据源最后更新时间 (没啥价值)

# 搜索

**匹配** != 搜索: `= text` / `LIKE 'text%'` / `LIKE %text%`

搜索相关 
- 搜索对象拆词
- 搜索文本拆词
- 搜索相关性排序规则
- 多主体搜索, 搜索优先级规则问题: 商品标题/正文/卖家/...

搜索规则是大坑, 但非常重要, 应该是目前数据产品最核心功能 (先找到数据), 需要专项跟进评估优化质量 !!!

# 筛选

形式:
- 单选
- 多选: 尽量不做, 或者改组选
  - 一定是OR逻辑, 否则做起来很麻烦
- 组选:
  - 优先走前缀索引匹配或数值范围筛选, 需要属性层级关系提前设定好, 例:
    - 字符层级: `where category like '103%'`
    - 数值层级: `where category>=1030000000 and category<1040000000`, 缺点: 层级深度结构必须提前规划好
  - 下策: 交互上转换为多选
- 反选: 尽量不做, 交互上一般是多选+排除
  - 技术潜在优化: `IN (...)` <-> `NOT IN (...)` 视IN长度决策
- 范围选: 尽量约化为指定范围区间选择, 从而优化ES来源数据筛选性能. 例:
  - 粉丝数任意区间筛选 改为指定几个范围区间分桶
- 分位选:
  - 力争不做, 高端BI分析类客户需求, 不宜功能页面体现
  - 例:
      - 销量占大盘超过5%的商品
      - 粉丝数超过95%的KOL

## 多筛选项组合逻辑

一定是AND逻辑

筛选组合关系厘清. 例子:
- 投放该地区媒体的广告
- 美妆频道带货类型笔记

分析:
- 原因: 投放地区/媒体不是广告单关系, 是广告投放多元关系/事实
- 频道/类型是笔记的二元关系/属性

## 筛选列表

- 可枚举/数量少: 直接页面体现
- 可筛选项较多 -> 筛选列表内的搜索控件

动态筛选列表
- 列表基于筛选项动态变化: 明确筛选项的主从关系, 单独做接口, 一般问题不大
- 基于框定主体数据变化: 一般不做, 因为筛选一般不区分先后顺序, 交互逻辑比较难以理解, 做起来比较麻烦

# 时间筛选

首先明确时间筛选的主体的什么时间. 避免同时框定多个时间筛选, 理解困难

时间控件选项
- 近N日: 可以将指标预聚合为属性
- 任意时间段: 只能查时汇总
- 产品设计上如非必要避免任意时间段筛选, 尽量弱化为近N日筛选, 从而预留时间相关指标转化为主体属性的可能性

注意: 明确近N日/小时/天的概念

## 时间筛选和其他筛选项的关系

明确区分主体固有属性 vs 主体时间段相关属性

例子: 直播推广的商品筛选?

技术决策: 时间筛选项相关属性筛选不能通过ES解决

# 搜索 vs 筛选

先筛选, 再搜索?

对于涉及时间筛选的, 应该先搜索再提示/改筛选时间, 或者交互上重新思考.

# 排序

一般是单指标排序, 不做组合排序需求 (`order by a, b`), 交互逻辑不好设计

尽量只做单向排序, 从而为技术优化预留: 大部分不会去到头部的数据提前裁剪优化数据量

# 搜索 VS 排序

- 简单匹配需求: 可以做指标排序
- 真搜索类需求
  - 默认按照搜索相关性排序
  - 不建议按照其他字段再次排序, 规则很模糊

产品页面设计规范: 榜单类页面禁止做搜索框, 弱化为榜单筛选框做简单匹配

# 聚合

聚合: 汇总 / `GROUP BY`

呈现形式: 主体指标 / 图

技术实现决策
- 从查询最优角度, 做预聚合, 每个功能接口只做筛选+排序
- 从灵活性角度, 优先考虑查时聚合

## 聚合 vs 时间

聚合一定是时间相关的, 暗含了时间筛选

不做历史至今全聚合需求, 尤其是历史至今UV指标

## 聚合时间衰减降维

数据时效性:
- 近期数据要更实时同步, 看更细粒度, 对于数据变更容忍度更高
- 远期数据不要求实时, 但是一般要求数据不变性 (如上月/N日前数据指标不应该再发生变化)

数据时间降维, 淘汰. 观察粒度随时间可以拉长, 如:
- 近3小时/按小时或分钟级统计
- 近N日/按天统计
- 近12月/按月统计
- 近几年/按季度统计
- 几年前数据淘汰

# 指标相关

属性 vs 指标 

- 属性:
  - 对象某种可枚举的单/多关系
  - 一般说的是枚举型, 或者是塌方关系 
  - 筛选用
- 指标:
  - 数值型
  - 对象某种关系汇总 
  - 排序用
- 属性聚合 -> 指标
- 指标分桶 -> 属性

## 指标需求取舍

尽量只做SUM/COUNT统计, 涉及平均单价之类要注意计算逻辑

聚合指标要求时间限定, 不做累计指标需求

## 避免不同时间段指标/属性综合交互场景

史上最坑爹需求:

- *当前*属性筛选 / *历史*时间指标排序
- *历史*时间相关属性筛选 / *当前*指标/属性排序 

时间相关字段对于表设计的影响: 尽量当作时间相关做, 否则对象属性变更涉及订正数据范畴太大

## UV类指标 / 去重问题

去重聚合 + 任意时间段筛选的场景无法预聚合, 功能评估时需格外慎重.

砍法:
1. 尽量砍成相对时间段内去重指标
2. 论述去重指标和非去重指标的区分价值. 尽量UV指标简化为PV

技术优化手段:
- Bitmap位图结构优化精确去重空间消耗
- 近似集合算法
- 移动窗口去重算法
- ...

# 加总讨论

加总: 加起来等于总数

主要出现在多关系主体视角层面

例子:

- 商品识别多单品, 各单品销量和 != 商品总销量
- 商品筛选推广方式看销量, 是否要求看该推广方式来源带来的销量?
  - 否则, 不同推广方式的销量和 > 总销量

应对办法:

1. 指标分摊, 满足加总需求, 如销量分摊
2. 多关系占比很少的情况下, 当作单关系处理, 用数据可控的不精确换方案的简单性

UV类指标天然不支持加总

## 加总对于表结构设计的影响

多属性如何冗余问题, 不好宽表直出, 必须特别处理

技术手段:
- 拆多行:
  - 数据更新状态维护复杂, 多标签变更时, 需要连带同步该表其他字段
  - 查时非常容易漏筛选导致算多
- 单行做列表: 同步数据相对灵活; 筛选性能不好
- 较少枚举值情况下做位图数值存 + IN 所有组合方式折衷
- 不冗余, 拆查询多阶段

拆多行具体一种方案:
- 加总标签列单独一个空值维护管理, 等于是单表做不同维度塌方聚合
- 不筛选多标签字段时, 默认补上一个ALL筛选

```
product  |category   |sales
A        |103        |100
A        |104        |100
A        |0          |100

select category, sum(sales) from tbl where category!=0 group by category
select product, sum(sales) from tbl where category=0 group by product 
```

# 非功能基本要素

以上是涉及实现功能相关, 这里简单列一下技术角度额外考虑的点:

- 数据量级
- 数据一致性
- 数据实时性
- 数据留存/淘汰
- 可订正/变更数据窗口, 历史数据相关不变性逻辑
- 数据接口SLA指标
- 其他非数据相关响应优化点
  - 请求网络耗时
  - 前端渲染耗时
  - 按需加载: 哪些元素可以异步化, 哪些必须要同步出现

# 数据源区分/规范

- MS: 基础会变的数据关系, 小数据量级下的方案
    - 单机方案
    - 索引主要用于筛选后更新
    - 主要优势: 更新 / CDC
- ES: 搜索, 禁止聚合逻辑
    - 适用属性筛选
    - 多筛选意图坑注意
    - 筛选+排序性能需评估
    - 集群支持, 查询集群可分解, 单查询角度可以当作是集群版MS使用, 充值变强
    - 瓶颈在于写入/更新
- CH: 一定是聚合查询(GROUP BY)
    - 禁止JOIN
    - 有限度的IN
    - 禁止实时单行写入
    - 不严格支持主键唯一, 需要业务角度容忍脏数据
    - 短期垂直扩容变强, 集群版本不能拆分查询计划, 需要进一步调研评估集群方案
- SQL over OSS/S3: 没有实时性要求的JOIN大乱炖工厂
    - 缺点: 费钱 / 不实时

数据同步一般流程: MS -> ES / CH

目前数据选型局限性, 新数据技术方案/使用姿势没有充分调研/试点清楚前, 先确保既有套路统一.

遇到性能瓶颈先优化结构设计, 实在不行要至少确保能加钱解决问题 (可扩展性).

# 数据方案选型评估五象限

1. 功能角度评估:
2. 非功能角度评估
3. 数据同步逻辑开发复杂度评估
4. 数据方案灵活性/可扩展性/预留性
5. 价值点数/成本权衡
   - 成本3要素
     - 开发以及(更大头的)数据维护人力成本
     - 时间机会成本
     - 服务器成本

# 最后几句话

- 产品 vs 技术: 产品是爸爸, 技术是妈妈. 约会(评需求), 领证(确认需求), 怀孕(开发功能), 出生(上线了), 培育(用户使用/反馈/运营/迭代优化).
功能上线不是结束, 而只是开始. 重点是培育/功能价值最大化!
- 灵活/将变更推迟到最后一刻 vs 过早优化是万恶之源
- 不想做甲方的乙方不是好甲方, 或者至少做一个有拒绝权力的乙方
- 最好的技术优化是合理化(砍)需求