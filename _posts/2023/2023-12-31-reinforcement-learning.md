---
title: 强化学习
---

主要是本书的阅读笔记: [强化学习](https://book.douban.com/subject/34809689/) by [Rich Sutton](http://incompleteideas.net/)

# RL / Reinforcement Learning

trial-and-error, delayed reward

二元体: **agent** interact with **environment** over time

三方面: 感知 sensation / 决策 action / 目标 goal

四要素
- policy: sensation -> action, 行动策略
- reword signal: 奖惩信号 (短期,及时行乐) / 量化, 容易测量
- value function: 价值函数 (长期,延迟满足) / 难以评估, 基于reward测算
- dynamics / environment / model: 运作机制, 环境

与监督学习区别:
监督学习, 通过对于训练集归纳, 预测未见数据.
相当于给了每种棋局的最优解法, 但是缺少学习体和机制的交互过程.
实际问题标注数据量很少, 质量也堪忧, 需要学习体不断实践拿反馈, 生成训练数据, 方可自学成才.

与无监督学习区别: RL的目标是最大化奖赏, 无监督学习旨在发现背后的结构. 当然理解世界运作机制有助于最大化奖赏, 不过这是个更难的问题. 

model-free VS model-based, 白盒还是黑盒学习?
- 白盒: 理解这个世界的运作机制, 或者做一个不太差的简化近似
- 黑盒: 不尝试去理解运作机制, 在这个世界苟下去, 或者活得更好

# MAB (Multi Armed Brandit) and EE (Explore && Exploit)

多个赌博机, 每个以一定概率分布输出奖励. 求一个策略, 找到最好的机位, 以最大化收益.

为什么叫bandit? 强盗, 赌博约等于抢钱

为什么没有单臂赌博机? one-armed bandit 单摇杆的赌博机, 除了退场, 没有选择的机会, 这里多臂还是多台机器没有区别, 主要是为了引入选择性.

策略选择类问题, 现实例子: 点哪家外卖, 活给谁干, 等等.

EE:  / 探索与利用

EE策略
- 贪心: 永远只取当前平均收益最高的
  - 受开局随机影响严重, 不一定能发现最优选择
  - 初始收益乐观冷启动, 给每个较高初始评分 (容忍度), 这样知道平均收益掉下来之后, 才尝试其他机子
- e贪心: 仍然贪心, 但是小概率选择其他
  - 缺点: 收益差的还是有恒定的机会被选择到
  - 对于不能永远反复下去的选择, 可以初始较大e, 之后逐步减少
- UCB (Upper-Confidence-Bound): 选择概率和选择过的次数负相关, 试过很多次表现都不好的被打入冷宫
- Gradient Bandit: 选择概率是累计奖励的softmax
  - 永远选择平均奖励数值高的 -> 较高概率选择平均奖励数值高的
  - 解耦奖励数值和选择概率
  - 类SGD的方式更新偏好数值

这里每个赌博机的奖励分布函数未知. 知道了, 相当于开了上帝视角, 拿着期望最大的使劲薅即可.

上面讨论只考虑了奖励函数是固定的 (stationary), 即以一个固定的概率分布吐钱. 需要学习就只是每个机子的期望收益数值.
如果奖励概率函数时间相关缓慢变化的 (non-stationary), 则平均收益做滑窗或者指数平均, 而不采用初始至今的算数平均即可.

再进一步, 奖励函数是有状态的, 以及受行为及奖励结果动态变化的, 比如基于当前机子累计收益给奖励, 如确保胜率, 确保收益, 及常见"十抽保SSR"之类等等.
则需要对于每个机子当前处于何种状态做预测, 以及当下状态下的最有选择评估.

探索与利用的困境: 应该面试到第几个人录用, 应该和第几个女友结婚?

如果人生是无限的, 或者可以随时重来, 那么多探索, 可以发现全部的可能性; 可惜在有限的一次生命中, 只能看一步走一步.

年轻时候机会成本低, 多探索; 年长后多利用所谓人生经验, 吃老本.

或者人生可能并没有什么当下奖励和最终目标, 只是为了获得经验

Gittins-index

...

# MDP / Markov Decision Process

马尔可夫假设回顾: 下一步只和当前相关, 和过去无关, 虽然极大的简化了问题形式. 但一般不成立.
比如和老婆吵架, 可能并不是因为今天的一件事, 而是历史逐步积累翻旧账触发.

MDP记号
- **S** / state / 状态空间
- **A** / action / 行为空间
- **R** / reward / 奖励数值
- **d** / dynamics / `P(St, Rt | St-1, At-1)`
  - 状态转移概率 `P(St|St-1,At-1)`
  - 奖励概率 `P(Rt|St-1,At-1)`
  - 条件奖励概率 `P(Rt|St,St-1,At-1)`
  - 可以是确定的, 也可以是概率的
  - `d(s1,s2,a,r) -> [0,1] for s1 in S for s2 in S for a in A for r in R`
  - 对比HMM: 显变量(奖励)完全基于隐变量(当前状态)表达, `p(s1,s2,a,r) = p(s1,s2,a) * p(s2,r)`
  - 对于学习体而言, d不一定是可知的, 但是S一定是可观测的, 或者换个说法, S是学习体的观测/感知, 而不是实际世界运作的底层变量
- **p** / policy / 策略 / `P(At|St)`
  - `p(a,s) -> [0,1] for a in A for s in S`
  - 同样的, 也可以确定的策略 
  - 为了避免混淆, 用大P记号概率, 用小p记号策略函数

这里简化讨论, 都当作离散问题表述, 即S/A/R可枚举.
实际连续问题也离散化去近似, 每一步的行为导致奖励以及状态的变化.
如奖励数值结果认为不可枚举而是个概率分布表示, 下面的讨论也可以简单将枚举求和做成积分形式表示即可.
(distribution model VS sample model).

MAB例子: 每个机子带了状态, 决定了当前奖励概率

下棋例子: S完全确定的, R是否获胜, A落子, d为对手

R很难制订, 和目标相关
- 最速通关: 每一步激励-1
- 活着别死/几条命/最少损失
- 最多击杀
- ...

R只告诉目标, 不透露方法:
例如下棋, 不能以吃子/损子作为R, 只在死棋状态时给出+1赢/-1输信号.
把R当作KPI, 怎么实现得自己琢磨.
好的R能帮助快速学习达到目的.
且不一定每一步都有奖励.

**G** Goal / 目标函数 / 贴现收益: 从当前步往后看, 最大化未来的期望累计奖励
- (continuing) 无中止态的, 是未来每步的折现奖励, 否则是个正无穷数了, `0<l<=1`折现率, 越接近0, 越及时行乐
- (episodic) 有中止态的, 直接求和, 相当于l=1
- 很多场景如游戏, 只有最后分出胜负才有奖励
- 从而在问题表述中消灭掉时间维度, 只留下了状态维度

```
G(t) = R(t+1) + l * G(t+1)
G(t) = sum(l**(i-t) * R(i) for i in t+1 ... T)
```

> 陶渊明 / 归去来兮辞: 悟已往之不谏, 知来者之可追.
>
> 李白: 弃我去者昨日之日不可留, 乱我心者今日之日多烦忧.
>
> 二仙桥大爷: 向前看

value function / 价值函数 / Q函数
- state value function / 状态价值函数 / `v(s,p)`: 在给定当前状态s及策略p下, 最终期望收益.
- action value function / 行动价值函数 / `q(s,a,p)`: 在当前状态s及策略p下, 采取行动a的期望收益.
- 两者是等效的

**Bellman方程**: 价值函数当前步和下一步之间的关系

```
v(s,p) = sum(p(a,s) * q(s,a,p) for a in A)
q(s,a,p) = sum(d(s,s2,a,r)*(r+l*v(s2,p)) for s2 in S for r in R)
```

价值函数是对于策略p的泛函, 即给定策略p, v是确定的可计算出来的.

策略的偏序关系: `p1 >= p2 iff all(v(s,p1) >= v(s,p2) for s in S)`.
偏序定义: 不是任意两个策略是可比较的, 不过最优策略(簇)的存在性是显然的.

MDP模型下的问题表述: 给定当前状态s, 求最优策略及对应的最大价值

```
pp(s) = argmax(v(s,p) for all possible p)
v(s) = max(v(s,p) for all possible p)
```

优化问题表述形式, 不过这里参数是泛函表述, 即函数族p, 而不是确定的参数数值空间.
标准优化问题对于策略结构做了明确的结构假设, 从而是参数化的表述形式.

对于最优策略下的价值函数, 类似的也有Bellman方程表示 (Bellman optimality equation)

```
v(s) = max(q(s,a) for a in A)
q(s,a) = sum(d(s,s2,a,r)*(r+l*v(s2)) for s2 in S for r in R)
```

表述了当前状态的最大价值和下一步每个状态最大价值的关系, 是可唯一求解的.
和上面的区别在于是否是对于策略函数p的泛函表示, 这里脱掉了p.

知道v(s), 自然也就知道了最优策略

```pp(s) = argmax(q(s,a) for a in A)```

举个下棋的例子, 知道了每一步落子的结果, 自然就知道了当下最优的选项.

到目前为止, "数学"层面的讨论结束了, 即存在性讨论, 任何MDP问题一定存在最优玩法.
往下是"算学"的工作, 即求解Bellman方程.

最简单的办法, 穷举. 但是问题随之而来.
维度灾难, 按照空间x状态x奖励空间的树展开搜索, 计算不可行.

此外, 对于简单的如下棋, 打游戏等场景, d可以认为是可知的, 或者说可模拟的. 对于一般现实问题, d是未知的, 后提.

# DP / Dynamic Programming

限定: d已知, 以及d和p是确定性的, 即非概率的.

**GPI** / generalized policy iteration / 迭代步骤
1. policy evaluation / 策略评估: 固定p, 评估v
2. policy improvement / 策略更新: 基于v, 更新p

乱入GPA: Grade Point Average 平均绩点 (成绩点数加权平均)

联想
- backpropagation, 前向(计算损失)后向(梯度更新参数)
- EM算法, E步观测响应度, M步更新模型参数
- GAN, 左右互博, 最终达到均衡, 收敛
- PDCA环, KPI考核周期, 即所谓不断的迭代

策略评估: 给定策略p, 迭代的方式拟合v(s,p), 一定是收敛的, 数值计算过程

policy evaluation
```
def get_v(p):
  v = {s: rand() for s in S}  // 价值函数随机初始化
  while True:
    e = 0  // 当前迭代步数值变化上界, 理解为v的F范数距离即可
    for s in S:
      new_v = sum(p(a,s2)*(sum(d(s,s2,a,r)*(r+u*v[s2])) for s2 in S for r in R) for a in A)
      e = max(e, abs(new_v-v[s]))
      v[s] = new_v  // 这里直接更新回原函数, 不单独维护两个再整体更新
    if e < min_e:  // 收敛退出条件
      return v
```

找更优策略: `p2 >= p1 iff all(v(s,p2) >= v(s,p1) for s in S)`

等价于: `p2 >= p1 iff all(q(s,p2(s),p1) >= v(s,p1) for s in S)`

greedy policy / 贪心更新策略: `p2(s) = argmax(q(s,a,p1) for a in A)`
即只调整当前一步, 找当前更优策略

policy iteration
```
def get_best_p():
  p = {s: random.choice(A)} // 初始策略随机初始化
  while True:
    v = get_v(lambda (a, s): 1 if p[s] == a else 0)  // get_v里面p是概率函数, 这里转化一下
    is_stable = True  // 策略是否不更新了, 即收敛到最优解了
    for s in S:
      old_a = p[s]
      new_a = argmax(sum(d(s,s1,a,r)*(r+l*v[s2]) for s2 in S for r in R) for a in A)
      p[s] = new_a
      if old_a != new_a:
        is_stable = False
    if is_stable:
      return p
```

这里每一轮重新估计v, 实际上是不需要的, 因为拿到的最大v等效拿到了最优策略, 因此上面的迭代argmax换成max后, 迭代算出最大v即可

value iteration
```
def get_max_v():
  
  v = {s: rand() for s in S}

  def q(s,a):
    return sum(d(s,s2,a,r)*(r+l*v[s2]) for s2 in S for r in R)

  def p(s):  // 注意由v唯一决定
    return argmax(q(s,a) for a in A)

  while True:
    e = 0
    for s in S:
      a = p(s)
      new_v = max(sum(p(s,s2,a,r)*(r+u*v[s2])) for s2 in S for r in R)
      e = max(e, abs(new_v-v[s]))
      v[s] = new_v
    if e < E:
      break

  return v, q, p
```

DP缺点: 每一轮遍历状态空间乘以状态空间, 费时 `for s in S for a in A`
办法: 偷鸡, 每一轮只访问一部分状态做更新.
类比SGD, 正常优化步骤, 是看完一整轮数据后再更新, 但是SGD每轮BATCH直接更新.

DP算法针对问题大小是多项式时间复杂度的`O(|S|*|A|)`, 尽管策略空间是`|S|**|A|`

可以看到, 不同状态下的预测用于计算其他状态下的值, 称之为自举 (bootstraping) 的.

这里DP是针对MDP问题形式的特别讨论, 广义传统算法上提的DP, 即动态规划, 对于问题的要求:
- optimal structure: 父问题最优解是子问题最优解的组合, 否则不能保证收敛到最优解, 只能叫贪心解
  - 正例: 最短路径问题/A*算法, 最大共现概率/viterbi算法, 编辑距离计算, 等
  - 反例: 背包问题
- overlapping sub-problems: 子问题的解是重复用到的, 从而可以通过memorization记住
  - 正例: 斐波那契数列
  - 反例: 归并排序, 快排, 只能说使用了"分治"的思路

也可把最短路径类问题当作一个MDP问题, d以及p是简单确定的, 从而便于理解.

# MC / Monte Carlo

DP里面要求d已知, 实际未知或者计算困难.
对于MC方法, 不要求知道d, 但是要求有中止态的 (episodic), 即假设最多T步结束.

MC: 大数定理, 反复多次观测, 最终观测均值一定收敛到期望

> 书读百遍, 其意自现

策略评估: 给定策略p, 通过反复的模拟采样, 利用观测平均价值去拟合v(s,p), 或者等价的q(s,a,p).

优点
1. 对于每个状态可以完全独立做采样过程, 而不是像DP这样基于其他状态结果 (即bootstrap特性)
2. 每轮采样计算和最终步长有关, 和状态维度无关, 显著降维
3. 可以选择从指定开始的状态去模拟, 而不用计算所有状态的价值, 更加实用
4. 每次都是整体跑完一轮, 对问题的马尔科夫性不敏感

EE in MC: 策略的随机性.
如果p是确定的, 则对于q(s,a,p)的估计缺少很多(s,a)的结果.
一种办法, 先乱走一步, 再遵循既定的策略 (Exploring Starts).

```

q = {(s,a): 0 for s in S for a in A}  // 表格形式行动价值函数

def p(s): // 当前策略
  return argmax(q[s,a]) for a in A)

d1, d2 = {}, {}  // 用于辅助记录模拟结果, 这里不记录每次详细模拟的记录

for _ in range(n): 
  s = random.choice(S)  // 随机开局
  a = random.choice(A)  // 乱走一步
  ss, as, rs = simulate(s,a,p)  // 模拟一局, 得到每一步的状态/决策/奖励列表
  g = 0  // 从后向前计算价值
  for t in range(T, 0, -1):
    g = rs[t] + l*g  // 当前步的折现奖励
    // first visit: 只记录状态和行动的第一次; every visit 则删掉下面两行逻辑
    if (ss[t],as[t]) in list(zip(ss[:t],as[:t])):
      continue
    sa = (ss[t],as[t])
    d1[sa] += g
    d2[sa] += 1
    q[sa] = d1[sa] / d2[sa]  // 更新回去从而更新策略 
```

first visit VS every visit: 观测序列里面是否允许包含当前预测态, every visit方式统计上来说结果有偏差, 但是更简单.

这里习得的是一个确定性的函数.
如果simulation过程中引入了EE, 如采用e贪心策略, 则整个过程可以去掉第一步的乱走.

# model-free VS model-based / 有模型学习VS无模型学习

环境, 即d是否已知, 注意这里model不同于ML里面常说的模型, policy才是RL里面的"模型".

有模型学习: DP, **expection updates**

免模型学习: MC, TD, **sample updates**

expection update: 都有分布了, 直接计算期望即可

sample update: 采样模拟近似

# on-policy VS off-policy / 同策略VS异策略

是否同策略学习, 即生成样本数据的策略和优化的目标策略是否为同一个.
off-policy里面会有两个策略, 一个用于价值函数评估 (target policy), 另外一个用于生成数据 (behaviour policy).

# prediction vs control

prediction problem: 策略评估, (给定策略的)价值函数求解

control problem: 找最佳策略

两者不能完全视为等同. 不过前者更容易一些.

# TD / Temporal Difference Learning

n-step TD: DP和MC的结合, n步以内用DP, n步之外用MC, n=0等同于DP, n=T等同于MC

开车的例子:
每一步是到达的途径点. 预测每个途径点到终点的用时.
注意奖励(即该段路线的耗时)是立刻给到的, 对于最终才给奖励如下棋游戏不适用.
自然对于上一段的预测做出修正.

为啥叫Temporal Difference? 时间差分, 或者说这里时间是每一步之间的预测和实际奖励误差, 用于更新回预测

difference (OR advantage in zero-sum game): 实际奖励 - 期望奖励

expect advantage = q(st,a) - v(st)

experienced advantage = Rt - v(st)

直观概念理解: 奖励超出预期的前几步给与正向的更新, 否则给与负向更新

0-step: 只奖励前一步, 实际上可能是延迟奖励, 如下棋的布局很重要; n-step: 对于前n步按照bootstrap结构分布奖励

SARSA (State Action Reward State Action): on-policy TD control

# Q-learning

off-policy TD control

近似`q(s,a)`

Why offline: target policy 是 greedy, behaviour policy 是 e-greedy (否则不可能收敛). 推断时候用 target policy.

TODO 为什么不去近似`v(s)` ??? 

# Tabular Method

state space planning

跑模拟, backup方式更新价值函数, 从而更新策略

基于模拟结果(experience)更新对于价值函数评估.

样本数据: 生成的还是提前准备好的, simulated experience vs real experience.

value/policy生成样本数据并用于更新回value/policy的称作direct RL.
反之, 通过学习更新回模型, 并模型预测出value/policy的过程, 称之为model learning.

从监督学习的视角来看, 模型更新是基于损失梯度回去的. RL是在是在试图习得评价函数, 并相应的制定最优策略. 当然你也可以说损失就是评价函数.


# Tree Search / 检索树方法 

decision time planning: "传统"检索树方法, 专注正对当前局势找最优解, 裁剪掉了很大一部分并不会访问的空间.

trajectory sampling: 按照当前策略进行采样

RTDP / real time dynamic programming:
不做全空间sweeping并expected updates, 而是做trajectory sampling updates. 对于一个固定的初始状态找到最优解.

根节点为当前状态.

rollout algorithm: decision time planning MC trajectory sampling

prioritized sweeping: sweeping遍历每种action, 随机采样, 或基于当前某种统计指标按照优先级采样.

## MCTS / monte carlo tree search

循环步骤
1. selection
2. expansion: 新增节点纳入考量
3. simulation / evaluate: leaf节点考量/跑模拟, 评价局势, EE策略从而优先预算里面活得最准确的Q估计
4. backup (statisitcs) / update: 更新统计结果

注意MTS的树结构在每一步之后可以复用, 即对手真的走了模拟的那一步后...

# Tabular VS Approximation Method

- Tabular Method: 小问题, 精确解, 表格, 所有的可能性都可以直接列出来的, 预案, 死记硬背式问题
- Approximation Method: 大问题, 近似解, 拟合输出
  - generalization / 从而具有泛化性, 处理未见场景, Tabular method就不行得跪 (没先例做不了)

function approximation 手段
- parametric function approximation: 学习w, 假设结构了
- memory based function approximation: 找个类似的经验套上去, 不假设结构, 近邻查找

# Eligibility Traces and TD(lambda)

n-step TD VS TD (lambda)

forward views: 往前看, 基于下面几步更新现在

backwrard views: 

lambda: 贴现率, lambda=0 ~ TD(0)

# 逼近价值函数 VS 逼近策略函数

基于逼近价值函数的策略: 贪心/e贪心/..., 回到EE探讨

# Policy Gradient Methods

之前的方法都依赖于价值函数逼近, 然后再得到策略. 另外一种手段是直接再策略空间里面找最优解.

参数化的策略函数`P(a|s;w)`, 然后最大化对应的损失/绩效函数 (performance measure). 从而回到了优化问题讨论模式.

策略函数是softmax模式, 自然很适合用ANN来拟合.

## REINFORCE method

即 MC policy gradient

REward Increment = Nonnegative Factor x Offset Reinforcement x Characteristic Eligibility

# actor-critic methods

policy gradient: 逼近策略函数

Q-learning: 逼近行动价值函数

actor-critic methods: 同时逼近策略函数和价值函数

更好的评价当然更有助于更快收敛

- actor / 演员: learn policy
- critic / 评论者: learn actor's current policy in order to criticize

# 和心理学/神经科学的联系

Law of Effect: 强化得到奖励的行为, 弱化收到惩罚的行为, 趋利避害.

认知地图 / cognitive maps, 基于模型的学习 / model-based algorithm.

model-free and model-based algorithm VS habitual and goal-based behaviour

多巴胺: 大脑的奖励信号

synaptic plasticity / 突触的可塑性: 大脑学习的基础.

The reward prediction error hypothesis of dopamine neuron activity

降低预期就能更快乐?

惊喜: 奖励超过预期

# DQN

https://deepmind.google/discover/blog/deep-reinforcement-learning/

DQN: deep Q-network, Q-learning with deep convolutional ANN.

一系列电子游戏 (类比小霸王学习机)

直接用视觉信号作为输入, 从而省掉了需要针对各种具体游戏的特征构建.
最近几帧一同当作输入, 从而更好的模拟出状态/MC特性.
虽然状态空间比较大, 但是动作空间比较小, 就手柄的几个方向和按钮.
输出的是动作. 所以学的是一个策略网络.

Q-learning with **experience replay**: 记住并不断重放 (St, At, Rt+1, St+1). 
从而提高学习收敛的稳定性.

# AlphaGo

围棋为什么更难? 维度更大, 且围棋的局势更难评估. 象棋等胜负更依赖单子能力, 相对较为容易.

MCTS + CNN的工程上的胜利

三个网络:
- 轻策略网络: 用于做rollout, 即跑棋局模拟, 监督学习后不再更新, 足够快从而能优先时间内跑很多模拟结果出来
- 重策略网络: 做sweeping策略, 即当下考虑每个落子的概率
- 价值网络: 做局势评估

局势评估 = r * v(s) + (1-r) * G, 即模拟和价值函数结果的组合, r参数更信任价值函数结果还是模拟结果

MCTS策略: 树结构检索+上述三网络作用的结果

初始用人类棋谱做监督学习, 然后self-play生成数据训练更新重策略网络和价值网络


## AlphaGo Zero

更清爽版本
- 一个更大的CNN输出两个头
- 不用人类棋谱训练
- 更简单的棋局编码方式
- 价值评估不跑模拟了 ???

注意上面重策略网络和价值网络是单独的对于自生成数据的训练, 但是实际评价策略又是基于MCTS的, 消除这种异构性.

AlphaZero: 不局限于围棋 

MuZero: 连规则都不知道

AlphaStar: multi-agent reinforcement learning


# Tree Search

为什么minimax方法和RL不同???

minimax认为对手和自己一样, 即model=policy.

alpha-beta cutoff: 

对于棋类游戏, 落子后的局势判定称之为 position value function, 不能视作 state / action value function

# 针对棋类问题的讨论

何为棋类游戏?
- 确定性: 不存在概率触发机制, 没有运气成分
- 完备信息: 双方的信息是相等的

打牌: 不算
- 打明牌算不算? 不算, 因为还有抽牌导致的随机
- 不带抽牌规则的打明牌? 不算, 规则不确保交互进行

backgammon: 或者更熟悉的飞行棋类游戏, 随机决定可行的动作

所以严格意义上的棋类游戏很无聊, 随机性, 以及未知性, 是乐趣的来源.
如游戏里面的暴击或者技能等触发概率 (不确定性). 战争迷雾 (不完备信息), 需要不断侦察对手策略以制定反击策略.

下棋当作RL问题: 环境即对手.

棋类问题, 最终赢得比赛才是目的, 奖励即胜负, 是最后才给的, 贴现率认为是1.

minimax: 己方, maximizer, 最大化score; 对手, minimizer, 最大化自己得分, 即最小化对手得分 
博弈论视角的 tree search

Game Theory

零和游戏: 自己得分 + 对手得分 = 0, 棋类游戏自然是零和游戏

> Zermelo's theorem: 在二人的有限交互进行游戏中, 如果双方皆拥有完全的资讯, 并且运气因素并不牵涉在游戏中, 那先行或后行者中必有一方有不败策略

问题解决的强度
- 超弱解: 存在性证明
- 弱解: 总初始状态开始保证赢
- 强解: 任意残局下都能赢

23年黑白棋被解决了(弱解)
- https://mp.weixin.qq.com/s/Vei01U463WiPSuQbZ5bW5g
- https://arxiv.org/abs/2310.19387

国际象棋/围棋并没有被解决, 只是电脑计算的近似策略胜过了人类
