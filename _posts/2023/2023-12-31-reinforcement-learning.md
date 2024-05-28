---
title: 强化学习
---

[强化学习](https://book.douban.com/subject/34809689/) by [Rich Sutton](http://incompleteideas.net/)

# RL

**agent** interact with **environment** over **time**

感知 sensation / 决策 action / 目标 goal

四要素
- policy: sensation -> action, 行动策略
- reword signal: 奖惩信号 (短期,及时行乐) / 量化, 容易测量
- value function: 价值函数 (长期,延迟满足) / 难以评估, 基于reward测算
- model / dynamics: 运作机制, 不一定已知

与监督学习区别:
监督学习, 通过对于训练集归纳, 预测未见数据.
相当于给了每种棋局的最优解法, 但是缺少学习体和机制的交互过程.
实际问题标注数据量很少, 质量也堪忧, 需要学习体不断实践拿反馈, 生成训练数据, 自学成才.

与无监督学习区别: RL的目标是最大化奖赏, 无监督学习旨在发现背后的结构. 当然理解世界运作机制有助于最大化奖赏, 不过这是个更难的问题.

白盒还是黑盒学习?
- 白盒: 理解这个世界的运作机制, 或者做一个不太差的简化近似
- 黑盒: 在这个世界苟下去, 或者获得更好

# MAB / multi-armed bandit / 多臂赌博机

多个赌博机, 每个以一定概率分布输出奖励. 求一个策略, 找到最好的机位, 及最大化收益.

bandit: 强盗, 赌博等于抢钱

现实例子: 买哪家股票, 决定点哪家外卖, 活分给谁干, 等等.

策略
- 贪心: 只取当前平均收益最高的
  - 受开局随机影响严重, 不一定能发现最优选择
  - 初始收益乐观冷启动, 给每个较高初始评分(容忍度), 这样知道平均收益掉下来之后, 才尝试其他机子
- e贪心: 仍然贪心, 但是小概率算计选择其他
  - 缺点: 收益差的还是有恒定的机会被选择到
- UCB (Upper-Confidence-Bound): 选择概率和选择过的次数负相关, 试过很多次表现都不好的被打入冷宫
- Gradient Bandit: 选择概率是累计奖励的softmax
  - 永远选择平均奖励数值高的 -> 较高概率选择平均奖励数值高的
  - 解耦奖励数值和选择概率
  - 类SGD的方式更新偏好数值

单臂赌博机? one-armed bandit 单摇杆的赌博机, 只要玩下去, 没有选择的机会, 这里多臂还是多台机器没有区别, 主要是为了引入选择性.
这里每个赌博机的奖励分布函数未知. 知道了, 相当于开了上帝视角, 拿着期望最大的使劲薅即可.

上面讨论只考虑了奖励函数是固定的 (stationary).
如奖励概率函数时间相关缓慢变化的 (non-stationary), 则平均收益做滑窗或者指数平均, 而不采用初始至今的算数平均即可.

此外, 实际问题中, 是有状态的, 受行为及奖励结果动态变化的, 比如基于当前机子累计收益给奖励 (庄家永不输), 及"十抽保SSR"之类.

## EE / Explore and Exploit

探索与利用的困境: 应该面试到第几个人录用, 应该和第几个女友结婚?

如果人生是无限的, 或者可以随时重来, 那么多探索, 可以发现全部的可能性; 可惜在有限的一次生命中, 只能看一步走一步.

年轻时候机会成本低, 多探索; 年长后多利用所谓人生经验, 吃老本.

Gittins-index

...

# MDP / Markov Decision Process

马尔可夫假设回顾: 下一步只和当前相关, 和过去无关, 极大的简化了问题形式. 一般不成立.
比如和对象一起交往, 当前没做好, 可能连带起历史恩怨翻旧账, 直接火力全开吵起来.

MDP定义
- **S** / state / 状态 / sensation / 感知
- **A** / action / 行为
- **R** / reward / 奖励, 数值
- **d** / dynamics / model / 环境运作机制 / `P(St, Rt | St-1, At-1)`
  - 状态转移概率 `P(St|St-1,At-1)`
  - 奖励概率 `P(Rt|St-1,At-1)`
  - 条件奖励概率 `P(Rt|St,St-1,At-1)`
  - 可以是随机的, 或者是确定的
  - `d(s1,s2,a,r) -> [0,1] for s1 in S for s2 in S for a in A for r in R`
  - 对比HMM: 显变量(奖励)完全基于隐变量(当前状态)表达, `p(s1,s2,a,r) = p(s1,s2,a) * p(s2,r)`
  - 对于学习体而言, d不一定是可知的, 但是S一定是可观测的, 或者换个说法, S是学习体的观测/感知, 而不是实际世界运作的底层变量
- **p** / policy / 行动策略 / `P(At|St)`
  - `p(a,s) -> [0,1] for a in A for s in S`
  - 同样的, 也可以确定的策略

这里当作离散问题表述, 即S/A/R可枚举, 实际连续问题也离散化去近似, 每一步的行为导致奖励以及状态的变化

MAB例子: 每个机子带了状态, 决定了当前奖励概率

下棋例子: S完全确定的, R是否获胜, A落子, d=对手决策

R很难制订, 和目标相关
- 最速通关: 每一步激励-1
- 活着别死/几条命/最少损失
- 最多击杀
- ...

R只告诉目标, 不透露方法: 例如下棋, 不能以吃子/损子作为R, 只在死棋状态时给出+1赢/-1输信号
把R当作KPI, 怎么实现得自己琢磨.
好的R能帮助快速学习达到目的.

**G目标函数 / 收益**: 从当前步往后看, 最大化未来的期望累计奖励
- (continuing) 无中止态的, 是未来每步的折现奖励, 否则是个正无穷数了, `0<l<=1`折现率, 越接近0, 越及时行乐
- (episodic) 有中止态的, 直接求和, 相当于l=1
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

- state value function / 状态价值函数 / `v(s,p)`: 在给定当前状态s以及选择策略x下, 最终期望收益.
- action value function / 行动价值函数 / `q(s,a,p)`: 在当前状态s以及策略p下, 采取行动a的期望收益.

**Bellman方程**: 当前价值函数和下一步价值函数的关系

```
v(s,p) = sum(p(a,s) * q(s,a,p) for a in A)
q(s,a,p) = sum(d(s,s2,a,r)*(r+l*v(s2,p)) for s2 in S for r in R)
```

v/q两者是不用区别看待, 等效的, 都可以叫做价值函数.
价值函数是对于策略p的泛函, 即给定策略p, v是确定的可计算出来的.

策略的偏序关系: `p1 >= p2 iff all(v(s,p1) >= v(s,p2) for s in S)`.
偏序定义: 不是任意两个策略是可比较的.
一定有存在(一个或一簇)最优策略.

MDP模型下的问题表述: 给定当前状态s, 求最优策略及对应最大价值

```
p(s) = argmax(v(s,p) for all possible p)
v(s) = max(v(s,p) for all possible p)
```

优化问题表述形式, 不过这里参数是函数族(p), 而不是确定的参数数值空间, 因为标准优化问题对于策略结构做了明确的结构假设

对于最大价值函数, 类似的有Bellman方程表示 (Bellman optimality equation)

```
v(s) = max(q(s,a) for a in A)
q(s,a) = sum(d(s,s2,a,r)*(r+l*v(s2)) for s2 in S for r in R)
```

表述了当前状态的最大价值和下一步每个状态最大价值的关系, 是可唯一求解的.
和上面的区别在于是否是对于策略函数p的泛函表示, 这里脱掉了p.

解出v(s), 自然知道了最优策略 (Q: WHY)

```p(s) = argmax(q(s,a) for a in A)```

到目前为止, "数学"层面的讨论结束了, 即存在性, 任何MDP问题一定存在最优玩法.
往下是"算学"的工作 (找到解): 求解Bellman方程.

最简单的办法, 穷举; 类比复仇者联盟终局之战, 穿越时空到每个可能性的平行宇宙, 找到当下最优的选择.

现实问题
1. 世界运作的机制d, 对于学习者来说, 一般是未知的
2. 维度灾难 (按照空间x状态x奖励空间的树展开), 计算不可行

# DP / dynamic programming

条件: d已知, 以及d和p是确定性的

迭代步骤 (GPI / generalized policy iteration)
1. 策略评估 / policy evaluation: 给定策略p, 评估v
2. 策略更新 / policy improvement: 基于评估v, 更新p

有点类似啥?
- DNN Backpropagation, 前向(计算损失)后向(梯度更新参数)
- EM算法, E步观测响应度, M步更新模型参数
- GAN, 左右互博, 最终达到均衡, 收敛
- PDCA环, KPI考核周期, 所谓不断的迭代

策略评估: 给定策略p, 迭代的方式拟合v(s,p), 一定是收敛的, 数值计算过程

policy evaluation
```
def get_v(p):
  v = {s: rand() for s in S}  // 价值函数随机初始化
  while True:
    e = 0  // 当前迭代步数值变化上界, 理解为v的F范数距离即可
    for s in S:
      new_v = sum(x(a,s2)*(sum(p(s,s2,a,r)*(r+u*v[s2])) for s2 in S for r in R) for a in A)
      e = max(e, abs(new_v-v[s]))
      v[s] = new_v  // 这里直接更新回原函数, 不用单独维护两个
    if e < E:  // 推出条件认为收敛了
      return v
```

找更优策略: `p2 >= p1 iff all(v(s,p2) >= v(s,p1) for s in S)`

等价于: `p2 >= p1 iff all(q(s,p2(s),p1) >= v(s,p1) for s in S)`

greedy policy / 贪心更新策略: `p2(s) = argmax(q(s,a,p1) for a in A)`
即只调整当前一步, 找当前最优的选项

policy iteration
```
def get_best_p():
  p = {s: random.choice(A)} // 初始策略随机初始化
  while True:
    v = get_v(p)
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

这里每一轮重新估计v, 实际上是不需要的, 因为拿到的最大v等效拿到了最优策略, 因此上面的迭代argmax换成max后, 即迭代算出最大v即可

value iteration
```
def get_max_v(p):
  v = {s: rand() for s in S}
  while True:
    e = 0
    for s in S:
      new_v = max(x(a,s2)*(sum(p(s,s2,a,r)*(r+u*v[s2])) for s2 in S for r in R) for a in A)
      e = max(e, abs(new_v-v[s]))
      v[s] = new_v
    if e < E:
      return v
```

DP缺点: 每一轮遍历状态空间费时 `for s in S`
办法: 偷鸡, 每一轮只访问一部分状态做更新.
类比SGD, 正常优化步骤, 是看完一整轮数据后再更新, 但是SGD每轮BATCH直接更新.

DP算法针对问题大小是多项式时间复杂度的`O(|S|*|A|)`, 尽管策略空间是`|S|**|A|`

这里DP是针对MDP问题形式的讨论, 广义算法上常提的DP, 即动态规划, 对于问题的要求:
- optimal structure: 父问题最优解是子问题最优解的组合, 否则不能保证收敛到最优解, 只能叫贪心解
  - 正例: 最短路径问题/A*算法, 最大共现概率/viterbi算法, 编辑距离计算, 等
  - 反例: 背包问题
- overlapping sub-problems: 子问题的解是重复用到的, 从而可以通过memorization记住
  - 正例: 斐波那契数列
  - 反例: 归并排序, 快排, 只能说使用了"分治"的思路

# MC / Monte Carlo

DP里面要求d已知, 且实际计算困难.

对于MC方法, 不要求知道d, 但是要求有中止态的, 假设最多T步结束.

大数定理, 反复多次观测, 最终观测均值一定收敛到期望

> 书读百遍, 其意自现

策略评估: 给定策略p, 通过反复的模拟采样, 利用观测平均价值去拟合v(s,p), 或者等价的q(s,a,p).

优势
1. 对于每个状态可以完全独立做采样过程, 而不是像DP这样基于其他状态结果 (即bootstrap特性)
2. 每轮采样计算和最终步长有关, 和状态维度无关, 显著降维
3. 可以选择从指定开始的状态去模拟, 而不用计算所有状态的价值, 更加实用
4. 每次都是整体跑完一轮, 对问题的马尔科夫性不敏感

EE in MC: 策略的随机性.
如果p是确定的, 则对于q(s,a,p)的估计缺少很多(s,a)的结果.
一种办法, 先乱走一步, 再遵循既定的策略 (Exploring Starts).

```
stats = defaultdict(list) // 观测记录, 可简化
q = {(s,a): 0 for s in S for a in A}  // 行动价值函数

def p(s): // 当前策略函数
  return argmax(q[s,a]) for a in A)

while True: 
  s = random.choice(S)  // 随机开局
  a = random.choice(A)  // 乱走一步
  ss, as, rs = simulate(s,a,p)  // 模拟一局, 得到每一步的状态/决策/奖励列表
  g = 0  // 从后向前计算价值
  for t in range(T, 0, -1):
    g = rs[t] + r*g
    // first visit: 只记录每个状态的第一次
    if (ss[t],as[t]) in list(zip(ss[:t],as[:t])):
      continue
    stats[(ss[t],as[t])].append(g)  // 对于当前(s,a)的价值观测
  q = {sa: avg(samples) for sa in stats}  // 到当前步拟合的结果
```

这里习得的是一个确定性的函数.
如果引入了EE, 如采用e贪心策略, 则整个过程可以去掉第一步的乱走. 伪码略.

on-policy VS off-policy:
生成样本数据的策略和优化的目标策略是否要求同一个, off-policy里面会有两个策略. 人是否能完全自学顿悟, 还是需要借助他人知识.
从定义来说, off-policy包含on-policy, 自然更为强大, 学下棋给不给棋谱; on-policy简单, 收敛更快.
对于上文e贪心策略而言, 属于on-policy, 收敛到一个仍然保留探索可能性的策略;
对于off-policy, 则有一个用于训练的策略, 以及输出一个可能没有探索的, 确定性的, "实战"策略.

first visit VS every visit: 观测序列里面是否允许包含当前预测态, every visit方式统计上来说结果有偏差, 但是更简单.

# TD / Temporal Difference Learning

TODO MC和DP的组合

# 棋类游戏不败策略

game theory

博弈场景: p ~ d

> Zermelo's theorem: 在二人的有限交互进行游戏中, 如果双方皆拥有完全的资讯, 并且运气因素并不牵涉在游戏中, 那先行或后行者当中必有一方有必胜/必不败的策略

- 棋类: 完备信息, 全部可见
- 牌类: 不算
  - 打明牌算不算? 不算, 因为还有继续抽导致的随机
  - 全抽完了算不算? 不算, 不确保交互进行
  - 麻将算不算? 打明牌? 每轮之轮摸一个出一个算不算?
- 游戏: 战争迷雾, 随机事件 (是否暴击等等)

解决的强度
- 超弱解: 存在性证明
- 弱解: 总初始状态开始保证赢
- 强解: 任意残局下都能赢

23年黑白棋被解决了(弱解)
- https://mp.weixin.qq.com/s/Vei01U463WiPSuQbZ5bW5g
- https://arxiv.org/abs/2310.19387

国际象棋/围棋并没有被解决, 只是电脑的策略胜过了人类


# MTCS / Monte Carlo Tree Search

蒙特卡洛树搜索


# Reward Model

奖励模型 (ChatGPT)

看强化学习的初始由头

TODO

# AlphaGo & AlphaZero

蒙特卡洛树搜索+深度神经网络

AlphaZero: 完全自学习, 不利用人类棋谱知识




# Reference

[苦涩的教训](http://www.incompleteideas.net/IncIdeas/BitterLesson.html)