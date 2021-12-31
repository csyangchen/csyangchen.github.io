---
title: Clean Architecture 阅读笔记
---

ref: <https://book.douban.com/subject/26915970/>

- 编程层面 (搬砖砌墙):
  - 结构化编程: 模块拆分, 函数, 功能解耦
  - 面向对象编程: 封装, 继承, 多态 (接口, DI, ...) 
  - 函数式编程: 不变性
  - 自由度的约束
- 组件层面 (盖房间): 
  - SOLID原则 (SRP/OCP/LSP/ISP/DIP)
  - 组件组织三角折衷: 
    - REP (Reuse/Release Equivalence): 按照便于复用组织, 兼容性保证 
    - CCP (Common Closure): 按照变更组织结构, 便于维护, ~ SRP
    - CRP (Common Reuse): 按照发布最小变更组织, 避免无用的依赖, ~ ISP 
  - SDP (solid dependency principle) / SAP (solid abstract principle)
    - 越稳定的越需要抽象接口化, IA图
- 架构层面 (整体建筑):
  - 隔离解耦, 以及开发/部署/运维角度考虑统筹折衷
  - 隔离
    - 分层
    - 功能
    - 模型
  - 团队拆分: 按照分层/功能特性/组件/具体业务分组
  - 解耦: 
    - 代码层面/部署层面/服务层面
    - 代码层面依赖/运行库依赖/进程级别依赖/服务调用依赖
  - 架构设计同心圆

软件架构师一定要参与具体编码.

软件(soft), 相对硬件(hard), 就是易于变化的. 架构设计关注变化适应性.

架构不关注功能问题, 关心实现的健康程度. 重要紧急矩阵.

软件开发三活动: Make it work / right / fast.

**好的架构, 将所有的细节具体的决定, 推迟到最后一刻.**
