---
title: Fundamentals of Data Engineering
published: false
---

https://book.douban.com/subject/35810423/

建立业务对于交付数据质量的信心, 即出现异常情况的时候不会第一时间怀疑是系统问题.


工程决策在于找折衷, 同时避免引入高昂利息的技术债务.

架构: 做出重要的决定 (什么是重要的, 即改变成本很高); 尽量消除不可撤回的决定


数据治理: 
- 可见性
- 元数据管理
  - 业务词汇定义
  - 技术元信息
    - 数据调度计算管线关系
    - 数据血缘关系
    - 数据结构定义
  - 运行指标
  - 参考枚举列表
- 数据负责人及问责制度
- 数据质量: 准确, 完整, 时效
- 数据建模设计
- 数据变更管理
- 数据互通性
- 数据生命周期管理
- 数据隐私合规


DataOps / 精益
- 自动化
- 可见性及监控
- 故障处置 (先于客户感知)


FinOps: 不要只性能优化, 要把其他因素纳入权衡, 如性能优化措施导致的人力成本, 可维护性, 等等. 以账单为目标, 而不是技术指标为目标.

# Reference

数据管理系统
DataKitchen

调度系统

airflow
dagster
Argo

https://kapernikov.com/a-comparison-of-data-processing-frameworks/

BI可视化工具

开源: superset, redash (已停止更新)

tableau / 收费商业, 没用过

各云厂商提供的捆绑工具




# Refence Link

https://dataopsmanifesto.org/en/



