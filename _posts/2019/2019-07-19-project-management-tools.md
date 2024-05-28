---
title: 项目工作流管理工具
---

# Kanban / 看板

Kanban一开始我还以为是拼音, 结果原来是日本人发明的词, 来自丰田的"精益管理".

基础元素是一个卡片 (Card / Issue / Ticket / ...), 俗点来说就是一个事儿.

横向分列看事儿的状态, 或者进度. 进度对应到工作流程的阶段.

纵向分行看事儿的维度 (Swimlines/泳道). 按照人, 或者组来分.

一横一竖, 谁事儿多, 谁进展较快, 一目了然. 方便进行横向的进度对比.

优先级管理: 每一列通过上下顺序标识优先级.

# 进度管理象限

- 发布版本: 对于客户端产品可能更有价值, 目前个人经历过的主要是后端项目, 没有太强的版本概念,
  基本上是功能做完单独发布, 不走版本火车统一发布流程.
- 迭代 / 里程碑: 用于统一框定一组任务的时间窗口, 从而更好的评估负载. 每个单独事情评估耗时

# gitlab issues

核心是围绕issue的标签管理, 对于标签稍作规划, 就能够实现各种维度的管理. 如版本, epic等等.
更改进度, 本质上是删掉一个标签再加上一个标签.

Milestone (里程碑) 支持, 本质上也是一个关联开始和结束时间的标签. 实现类似敏捷迭代 (agile sprints) 或者版本 (release) 的管理.

gitlab的每次迭代也对于项目管理做了更好的支持.

很多是非免费版体验不到的功能. 比如说epic管理, 分指派人的面板, issue weight (需求点数), 多面板等等.

# JIRA

只能通过Workflow (工作流)来分. 和Trello区别的一个点.

issue的描述格式支持较为简单, 还是要组合Confluence一起使用. 如事情的调研结果等等.
一般用法JIRA记录过程数据, Confluence记录结果数据/文档/知识. 毕竟不能影响自家其他产品售卖吧.

工作流支持节点审批人权限? 从而避免随意改状态

JQL很强大, 基于JQL可以做任何自己想看的面板.

对于迭代管理更好的支持

分类象限非常多
- issue types
  - Epic / 个人理解
  - Story / 偏向从用户故事角度来
- component
- version
- tag
- ...

功能非常完备, 过于复杂, 日常小团队落地, 需要裁剪使用.

JIRA也意识到这个问题, 所以支持 [Simplified Workflow](https://confluence.atlassian.com/jirasoftwareserver0713/using-the-simplified-workflow-965542321.html)

和gitlab能够做到自动issue关联.

## JIRA vs OKR 映射

日常文档写OKR, 缺少结构化. 真正做的时候需要重复一遍到项目管理工具.
是否有可能直接OKR管理工具和项目管理工具整合???

# Trello

Jira同一家, 侧重点不同, 更加轻量, 对于非技术人员更加友好.
不过有限的使用经验来看, 和简单的TODO list工具区别不是特别大.

# Redmine

也是另外的免费的选择. 印象中更加传统, 上个世纪的UI交互设计.

Jira + Confluence 丐版.

文档编辑默认 Textile, 不过也可以改成 Markdown

不支持标签管理. 只能通过分类和版本两个维度进行划分.

工作流是固定的.

支持需求关联管理.

需要人工登记工时.

重点: 原生没有看板的支持 !!!

交互不够便捷, 已经习惯了通过看板拖动, 或者命令行的快捷更新方式, 很难再接受打开每个issue, 编辑的操作方式.

没有商业化的支持, 还是很难做到气候.

缺点是, 每个事儿只能指派一个人, 其实很多任务需要几个人高度协作才能完成的.
但是统一个事情拆几个分人的JIRA, 实在是不必要的麻烦. 而且每个人负责要做的东西不是订立计划的时候就能够体现出来的.

# 总结

本质上功能集合都是比较类似的. 重点在于如何结合项目进行分类.

gitlab的issue需要用markdown来写, 对于非技术来说不是特别友好.

项目较大之后, 选择Jira应该是合适的方案. Trello的推出可能也是觉得Jira过于重量, 不利于新用户吧.
以国内的情况, 估计很少公司会掏钱买Jira.

小团队, 对于技术同学比较友好的方式是用gitlab来管理项目. 业务同学可以通过教育解决.

工具不重要, 重要的是还是大家能够统一思想/流程, 把一种东西用熟. 简简单单Excel跟进工作也不是行不通.

# Reference

- <https://en.wikipedia.org/wiki/Kanban>
- <https://about.gitlab.com/solutions/agile-delivery/>
- <https://docs.gitlab.com/ce/user/project/issue_board/>
- <https://docs.gitlab.com/ce/user/project/milestones/>
- 互K文
    - <https://www.atlassian.com/software/jira/comparison/jira-vs-trello> 由于是两个都是自己家的, 互夸
    - <https://www.atlassian.com/software/jira/comparison/jira-vs-redmine>
    - <https://www.atlassian.com/software/jira/comparison/jira-vs-github>
    - <https://about.gitlab.com/devops-tools/trello-vs-gitlab.html>
    - <https://about.gitlab.com/devops-tools/jira-vs-gitlab.html>
