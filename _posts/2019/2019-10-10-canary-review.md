---
title: 自助报表功能设计
---

内部系统最多的就是各种看报表数据需求, 做多了当然希望尽可能的以自助的方式实现, 不要涉及过多开发工作.
这里记录内部一个自助报表服务的实践.

思路就是把用户交互操作直接翻译到SQL:

- 维度选择: GROUP BY
- 筛选: WHERE / HAVING
- 排序: ORDER BY

# 报表字段分类

- 时间字段: 对于详情表, 可能是原始时间戳, 如订单表, 对于报表而言, 一般是该行汇总到小时或者天维度
  - 默认必须要对时间字段进行筛选及聚合, 不考虑CRUD类型的非聚合数据查看需求
- 维度字段: 相关ID, 如产品, 用户, 销售等, 为了方便筛选, 相关冗余字段也要做进去, 如产品所属部门, 销售负责人等.
- 指标字段: 如`sales`, `incomes`, 默认通过`sum`汇总, 因为抛开维度谈`avg`/`max`等意义不大
- 虚拟字段, 可能会关联到同一行其他字段:
  - 虚拟维度字段:
    - 单行内转换的: `date(ts)`, `hour(ts)`, `case field when ... then ... end`, 等
    - 虚拟他表维度字段, 为了有限度的弥补JOIN需求: 没有在表内冗余的字段, 或者不允许冗余的维度字段, 要定义好关联关系, 查询时翻译为`IN (...)`
  - 虚拟指标字段, 如平均客单价`sum(incomes)/sum(sales)`, 投放地区数`count(distinct area)`等 
- 查询性能考虑, 视字段特性, 要区分标记为可筛选/可聚合/可模糊搜索/可排序等, 并在UI上体现出来
  - 虚拟字段一般标记为不可筛选 (但可聚合), 虚拟他表字段做聚合很麻烦 (得翻译成`case ... when ...`), 因此只做筛选

# 筛选列表

报表里面记录的都是ID, 然而业务需要看到的是名字, 这里要定义每个可筛选字段的, 也用于生成个字段的筛选列表.
在拿到数据的时候再按照映射关系翻译一次展示.

列表字段会比较多, 限定返回条目, 在用户筛选列表输入时触发二次搜索, 这里对ID或者NAME字段同时做前缀匹配搜索, 确保查询友好.

为了提高列表字段筛选有效率, 默认返回的是当前时间出现在该报表中的选项 `select distinct gid from stat where ts between ... and ...`.

进一步的动态列表是要跟据其他列表选项做进一步的过滤, 如筛选了指定地区, 产品列表只要该地区有投放的列表
`select distinct gid from stat where ts between ... and ... and area in ...`.

这里要在便捷性和查询性能之间找折衷.

# JOIN相关

性能角度以及交互实现的考虑, 不考虑生成JOIN表的逻辑. 跟据具体业务需求做冗余汇总报表.

- 一一映射关系的, 直接二次查询展示
- 简单的, 数量可控的关联查询, 通过虚拟维度字段定义, 执行时翻译成事实表相关字段IN逻辑实现.
  - 注意是分开查询, 充分利用查询缓存, 也部分解决了维度表和报表不是同实例的情况
- 一些有时间限定的属性 (如产品销售关系, 不能按照当前的归属来统计历史业绩), 或者筛选结果数量不可控的字段, 还是得通过冗余字段的方式直接筛选.

# 同比环比需求

翻译为两个相同的查询, 不同的时间条件. 然后相同维度行合并到一起展示, 并对指标计算出变化率.

基于同比环比变化率排序的需求, 需要拼接成两个结果表JOIN后排序的逻辑, 一般查不动, 而且返回结果不好翻译. 因此没做.

大部分按照本期固定指标的排序, 基本能够满足需求.

# 汇总行

一般报表需要个表头汇总行, 实施过来就是不加维度筛选的结果.

- 汇总行: `select sum(sales) from ... where ...`
- 数据行: `select aid, sum(sales) from ... where ... group by aid`

注意不能够基于数据行指标列求和来算汇总行, 因为诸如UV/平均价格等指标求和后没有意义.
汇总行的计算其实开销也很大, 因此UI上增加是否要汇总行的选项, 默认不选.

对于一些透视图的需求, 由于主要用的是垃圾MySQL, 因此不在功能上支持, 业务方多个查询自行解决 (或者导出Excel再加工).
在交互上提供点删除本列取消该列聚合, 选择本行增加特定筛选等短路操作.
如果确实需要的话, 对于一些简单指标的聚合也可以直接在客户端来实现, 因为提供的数据已经是完备的.

# 分页逻辑

不做数据库里面的分页, 对于查询结果返回前端时分页. 因为`GROUP BY`操作在数据库里面已经是一次全量计算了.

不做分页的一个好处是, 一些排序可以直接前端做, 交互上响应更快. 但需要前端保留原始排序信息, 否则一些会按照文本排序, 得到错误的结果.

为了避免各别查询条件下返回过多数据行, 查询默认加上`LIMIT 10000`条件, 大部分场合不会触发到.

一些确实需要看总数的逻辑, 通过虚拟字段的方式来统计到.

# 自定义视图

每个用户希望的默认查询参数都不一样, 因此要给用户创建自定义视图的功能.
做法将用户的请求参数保存下来即可, 这里需要保留的用户筛选的相对时间段, 并每次查询的时候翻译为具体时间段.
注意不能偷懒所有请求参数丢链接里面, 要创建一个真正的视图ID, 把具体查询参数存在后端, 从而方便修改.
自定义视图链接可以分享 (被分享人只能看不能修改), 被分享人也可以基于该视图再创建一个新的个人视图.

# 查询优化

对于MySQL里面的报表, 数据量大了很难一表走天下, 需要跟据不同汇总维度及筛选条件做预聚合表.
跟据具体查询条件, 判定并返回一个最优的聚合表进行查询. 如:

- `aid_bid_country_stat` 细粒度表
- `aid_country_stat` 不涉及bid字段的查询需求
- `country_aid_stat` 进一步优化指定country探查的需求
  - 加二级索引能够部分解决问题, 但是量级大了后不解决问题, 还是需要换主键顺序做新表

以上严格执行报表命名规范(按照primay key字段顺序命名), 并确定最优匹配映射规则:
- 筛选字段先于聚合字段的优先
- 多个满足条件的, 最少维度表优先

预聚合报表的数据一致性是另外一个比较大的问题, 这里不展开.

对于列表字段, ID到名字映射等一般不太变化或者脏读不敏感的逻辑, 可以通过缓存来优化.

# 报表版本及缓存

上游数据没有发生变化的时候, 不需要重新查询. 假设数据库每行有个ut最后更新时间戳:

- 查询数据版本 = `select max(ut) as version from tbl where ...`, 并且显示在UI上, 给客户一个明确的数据时效信息
  - 相对于算具体数据, 这个查询开销相对是比较轻量的
- 每次重新查询先看下查询数据版本是否变更, 如否, 直接返回上次缓存结果, 从而最大化的利用缓存, 且避免了脏读问题
- 这个数据版本也是出现数据问题时便于和业务方撕逼/确认的依据, 也是对外导出数据存档的一个标识

# 前端样式

一般报表数据需要连接到其他页面, 如产品详情, 等. 字段定义返回前端的HTML样式, 从而报表内链接直接跳转到对应运营页面.

此外, 一些样式的调整, 如列最大宽, 数值展示形式, 文字是否允许换行, 表头字段HOVER的解释文字, 也是通过配置生成.
前端开发不涉及任何业务逻辑.

对于字段比较多的场景, 一般会有调整列顺序, 冻结指定列的需求. 我们前端默认将维度列冻结, 便于左右拖动看指标列.
交互上也支持调整列顺序, 以及冻结/解冻指定列的功能. 不过做起来交互设计比较纠结.

同样比较纠结的是多字段排序的需求, 怎么都做不对, 最终的做法是按照列排序顺序来做解决问题.

时间筛选及时间聚合粒度同样是交互上我们做不好的地方, 最终解法还是通过定义各粒度的虚拟时间维度字段.

# 权限管理

- 行权限: 限定权限组可以筛选的相关表的字段控制
- 列权限: 限定权限组查询时需要增加的WHERE语句

这个没啥好多说的, 在后端一个预处理层解决, 不和其他模块发生过多交互.

# 指标筛选及告警管理

指标筛选, 翻译成HAVING语句

业务对于一些指标触达阈值希望能够及时通知到, 自行针对该自定义视图创建定期任务, 判定返回有数据时触发相关通知操作, 如发邮件, 即时消息等.

更进一步可以做一些自动化运营规则, 如停止投放, 调整价格等, 通过配置对应的webhook的方式来实现.
需要内部系统API打通/适配参数规范.

# 总结

将常见数据查询需求翻译成确定的查询计划可控的语句, 从而解放相关开发需求.
通过虚拟字段屏蔽了业务需求和具体实现的差异, 并在后续查询慢的时候进一步做冗余字段优化查询.
技术同学可以更专注在报表数据计算/同步的维护工作上.
后续我们将大部分查询直接基于Clickhouse的大宽表进行, 更进一步减少了统计表的维护工作.