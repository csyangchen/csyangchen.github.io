---
title: 检索技术及向量数据库
---

基础索引
- 哈希 / hash / O(1): 等值检索
- 排序树 / b-tree / O(log(N)): 全排序检索
  - 数值检索
  - 前缀/后缀匹配

数据库索引难点:
- 不光算法考量, 还有实际IO考量
- 充分利用多个索引信息 (多临时序列高效求交问题), 查询计划的索引选择及选择性判定问题

常见索引优化策略:
- `select id from user where name=?` 不定长字段构建索引存储开销较大
- 定长辅助索引节约存储开销: `index digest(name)`
- 数据分区, 减少单词查找索引所需深度: `partition by name[:2]`

其他业务场景需求:
- 关键词/子序列检索: `LIKE '%XXX%'` / `LIKE '%XXX%YYY%'` 
   - 关键词回溯场景
- 最长连续公共子序列检索:
  - 是否收录类似站点
    - www.website1.com -> web.website1.com
    - www.website2.com -> website2.com.cn
    - ~~blog.website3.com -> www.website3.cn~~
  - 是否可能见过的实体名
    - {雕牌肥皂, 丽水雕牌} -> {雕牌}
    - {丽水雕牌肥皂} -> {雕牌}
  - 相当于只能首尾插入或删除的编辑距离检索, 可部分利用数据库前缀后缀索引
  - ref db_search_xxx: 子序列遍历, 数据库前缀/后缀最优匹配
- 距离检索:
   - 近似文本查找: `where edit_distance(x, y) < d`
   - 相似图片判重: `where bit_count(x ^ y) < d`

距离检索之天真办法: 额外辅助索引 `idx_bit_count = bit_count(x)`
- `where idx_bit_count between bit_count(y) - d and bit_count(y) + d and bit_count(x^y) < d`, 筛选性太低
- `where idx_bit_count = bit_count(y)`, 损失太多, 假设一定1位数目相同只是位置不同
- 常见索引优化策略/天真办法的思路至少是合理的: 长数据找个短标示便于辅助索引, 等值判定后再后过滤, 一定损失换速度

# 字符串匹配算法 / string matching

Q: `needle in haystack` 是如何实现的?

- naive: - / O(mn) / -
- Rabin–Karp: O(m) / O(n) ~ O(mn) / O(1)
  - 对子序列定义一个数值函数, 等值比较相等后才详细校验, 否则跳过
  - 计算函数: 幂和, 可基于前值增量计算, 开窗长度m
  - 预处理: 提前算完needle的"特征值"
- KMP (Knuth-Morris-Pratt): O(m) / O(n) / O(m)
  - 构建前缀回溯字典
- BM (Boyer–Moore): O(m+k) / O(n/m) ~ O(mn) / O(k)
  - 额外预处理换平均计算复杂度
  - k: 词表大小
  - 字符串匹配算法的基线
- AC (Aho–Corasick): KMP变种, 一心多用, 同时匹配多词
- Two-Way: O(m) / O(n) / O(log(m))
  - 前向KMP, 后向BM
- 针对多数据过滤, 预处理构建可以忽略, 实际应用中, 更关注额外空间开销及最差复杂度

> 哲思: 失败是成功之母, 从不匹配中尽可能抽取有用的信息

Python: 短文本 Boyer–Moore–Horspool (BM简化版), 长文本 Two-Way

<https://github.com/python/cpython/blob/main/Objects/stringlib/fastsearch.h>

字符串匹配自动机
- DFA: Deterministic Finite Automata
- FSM: finite state machine
- 匹配树 -> 回退指针 / backtrack
- 结点: 匹配状态
- 中止结点: 完全匹配
- 正则匹配: NFA

检索: 针对海量的haystack文本构建有效的索引结构, 从而快速框定小样本目标数据

# 文本搜索

information retrieval / search / full-text search / ...

备忘
- characters / 字母 / alphabet
- term / 词元 / 单词 / word / token 
  - vocabulary / dictionary / lexicon / 词典 / 词表
- phrase / 短语
- sentence / 句子
- document / 单个文档
- corpus / 数据集 / 语料

文本搜索需求

- 子序列匹配: `LIKE '%XXX%'`
- 逻辑检索 (boolean search): `term1 AND term2 AND NOT term3`
  - 输入不需再分词等预处理, 最基础检索形式
- 普通检索: 允许命中文档不包含检索词, 基于输入文档及检索文档相似度排序返回
- 近邻匹配 (proximity search): 对检索词先后顺序/相对距离额外要求, 后处理过滤掉
- 模糊匹配 (fuzzy search): 允许对输入一定改写后匹配, 相当于输入纠错
  - 检索输入指定编辑距离内的全部有效词, 可基于词频再筛选
  - 文本查重: 理解为更长文本的编辑距离检索, 以及更复杂的编辑动作, 如整段句子位置对调等.
- "精准"匹配 (phrase search)
  - 实现手段: 近邻匹配, 约束命中词相对距离为0
  - ES: match_phrase + slop=0 
  - 保证了精度1但无法保障召回1, 能否认为等同于子序列匹配?
    - 不能, 分词可能导致不能全召回
- 语义检索/知识问答: 基于意图/内容
  - e.g. 广州市长是谁?

## 词包模型

bag of words / BoW

文档 = {词: 频数}

再弱化一点: 词集? 文档 = {词}

- 优点: 极大数据压缩
- 缺点:
  - 丢失序列信息: 美国/比/中国/强 = 中国/比/美国/强
  - 严重依赖于词表选择及分词质量
  - 视作表征向量时是极端高维且稀疏的
  - 语义近似检索效果不好, 同一个概念多种表述方式, 无法都通过同义词方式召回回来

## 倒排索引 / inverted index

- 有损存储: `{term: {doc_id: freq}, ...}`
- 无损存储: `{term: {doc_id: [offset, ...]}, ...}`
  - 可用于支持临近搜索, 但存储需求显著增长

检索过程: 输入预处理 -> 查找倒排索引 -> 求交 -> 后处理 -> 评分排序

## 搜索场景分词诉求

分词 / parser / tokenizer / cut / ...

带入数据分布先验做数据压缩

- 基于语言先验的, 有监督训练的切词
- 无监督的切词手段 / NN预处理用, 单词筛选性偏低, 不适合搜索场景
  - BPE / ...

构建索引时分词: 细粒度拆分, 冗余分词, 提召回. 缺点: 倒排索引数据量膨胀. 极端情况: n-gram 分词.
搜索时视情况可选择不同的分词器保精度. Q: 为什么会掉精度? 检索时输入文本也应冗余分词么?

## n-gram index

- 对文档做n-gram冗余分词索引
  - min_gram > 1 / 或使用停用词
  - max_gram 不可能检索所有数据, 数据爆炸了
- 搜索时只需要一种切法即可
  - `LIKE '%XXXYY%'` XXX及YY后再处理判定位置是否链接, 同精准匹配

场景: IDE搜索

https://dev.mysql.com/doc/refman/5.7/en/fulltext-search-ngram.html

https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-ngram-tokenizer.html

## 编辑距离检索

场景: 拼写纠错, 搜索召回, "你是不是要搜索..."

naive approach

- abc距离1索引词: {ab, bc, ac, ab?, a?c, ?bc, abc?, ab?c, a?bc, ?abc}
- 纳入索引
- 检索时, 距离1索引词查找
- 索引时不构建?, 检索时则需枚举所有具体词

长度n单词, 字表k
- 距离1 <= n + n*(k-1) + k*(n + 1) = (2k+1)*n+1 
- 距离2 < (2k+1)*n+1 + ((2k+1)*n+1)**2 
- 距离m ~ (k*n)**m

[Levenshtein_automaton](https://en.wikipedia.org/wiki/Levenshtein_automaton): 给定词表构建, 找出所有编辑距离m内的有效词.

一般针对给定词典做, 任意文本编辑距离, 先分词拆解处理

> TODO DEMO TIME

## 排序评分 / TF-IDF / BM25

- IDF: inverse document frequency
  - `ft = Nt / N` 出现该词文档比例  
  - `- log(ft)` 词的全局的稀有度 
  - IDF向量: 词对于文档的统计分布
  - IDF thresholding -> 停用词过滤
  - `sum_t(-log(ft)*ft)` 语料熵? / 词表停用词选择, 最小熵减
- TF: term frequency
  - `Ntd` 
  - 未正则化的 = 频数
  - 观察: 文本复制一遍不应该导致更相关
    - 措施: 频数改为频率, `ftd = Ntd / len(D)`
  - 观察: 一个文档反复堆砌一个词时不应该有线性的评分提升
    - 措施: 非线性化手段, 如 `log(ftd)`, `Ntd / (Ntd + k)`, ...
    - 传统TF-IDF评分 = `sum_t(log(ftd)*log(ft))`
    - 后者更可取, 因为更加平滑, 且上限趋向1 
  - 观察: 都命中条件下, 优先考虑更短的文本, 认为指代更明显
    - 措施: 除以文本长度
    - `len(D) / avg(len(d))` 相对文本长度越大, 权重越低
- BM25: `Ntd / (Ntd + k * (1-b + b * len(D) / avg(len(d))))`
  - `b` 参数越大, 文本长度影响越大, 0时忽略文本长度考量
  - 归一化到了[0, 1)区间

语言模型视角解读 / The query likelihood model

其他的排序规则混合: 文档的属性, 如重要性, PageRank指标, ...

## 向量计算视角的全文检索

文档的TF矩阵, IDF向量

输入检索词 -> 独热向量Q

`numpy.argmax(Q * TF @ IDF)`

也可以把IDF向量提前分解到TF矩阵上, 记作TF-IDF矩阵

解释:
- 词袋向量加权IoU
- 互信息最大化

> DEMO TIME

# 词向量

词嵌入 / Embedding

词包模型:
- 简单容易解释
- 缺陷:
  - 独热编码, 维度高, 稀疏
  - 不能很好处理歧义词 (一词多意)
  - 不能很好体现相似词 (多词一意)

词向量:
- 分布式/局部式表示
- 维度低 ~ 几百
- 稳健性 / 易扩展
  - 加新词时处理办法
- 可通过词向量内积更好的表达相似性
- 缺陷:
  - 难以解释

词向量的学习, 本质上基于邻近词共现概率的学习 (两词向量内积 ~ 共现概率)

- 朋友的朋友也是朋友, 等价概念理解
  - {番茄炒鸡蛋, 西红柿炒鸡蛋} -> 番茄 ~ 鸡蛋, 番茄 = 西红柿
- 通过共现体现出短语的不同语义
  - "river bank" vs "bank of china"
- 初步的逻辑关系抽取
  - 北京 + 中国 - 法国 = 巴黎
  - 3D区不能没有__, 就像西方不能失去耶路撒冷

## 主题向量

LSA (latent semantic analysis): 文档TF-IDF矩阵SVD分解 (W=USVt-> 左特征向量 (词主题向量) + 特征值 (主题权重) + 右特征向量 (主题在语料的分布) 

主题 = 认为出现一个词的时候, 在说一个主题的概率较大; 或者反过来说, 一个词被多大的可能纳入描述某个主题的文章中
- 烤肉 =  0.8 * 做饭 + 0.0 * 宠物 + 0.5 * 露营
- 小狗 = -0.2 * 做饭 + 1.0 * 做饭 + 0.5 * 露营

文档分类(主题)标注 -> 指定Vt -> 习得词对于分类的贡献概率

LSA矩阵维度: 词表 x 主题

## 主题向量 VS 词向量

- 主题向量, 维度等于隐式习得的主题数(也可能截断掉), 词包模型发展出来, 全局概念, 文档分类
  - 学习快 (传统矩阵分解算法)
- 词向量, 维度预先假定下来, 上下文习得, 捕获局部信息; 
  - 学习慢 (一层神经网络)
  - 一种朴素的基于词向量的文档向量 = 词向量加和; 也可类似LSA一样, 分解降维, 做聚类
  - 更加适合短语/句子层面做文档分析 (参考相似文案/商品标题推荐业务功能)

都可以认为式无监督的学习方法 / 自编码

## 文档的向量化表达

词向量: 缺点, 词向量习得后固定, 与上下文无关
深度学习: 超越邻近词视距, 更复杂的交互结构, 词向量上下文/全文深度相关

回顾BERT:
- 第一层一个Embedding / embedding layer
- 每个词向量叠加位置信息后, 继续走网络结构交汇, 注意力机制, 习得一个上下文感知的词向量(维度随心假定), hidden layer, 可用于继续做下游任务
- 最后接个分类/输出层, 如做序列标注任务; 通过特殊标记词分量, 或所有输出向量池化后, 做全局分类任务等

词向量 -> 模型计算 -> 文档向量 -> 分类输出层

相似的文档, 表征的文档向量应相似, 因此可直接检索文档向量做语义搜索

## gensim / fasttext

传统NLP艺能工具

gensim.models.LsiModel / gensim.word2vec

fasttext: 
- 加速训练手段
  - hierarchical softmax
  - n-gram 忽略顺序
- 量化手段减少模型大小
- 训练推断封装, 鼓励直接命令行使用, "外行"都能用

# 哈希 / 特征向量 / LSH

> hash: chopped meat mixed with potatoes and browned

哈希: 接受不固定的输入, 输出定长的字节, 以期捕获输入的某种特征

CHF (cryptographic hash function)
- 要求1: 输出空间的概率是非常均匀的 / any output comes with prob 2^-n
  - 满足这一点可可以用来做哈希数据结构, 但是不能用作安全场景的哈希
- 要求2: 难以逆向 / one-way properties, 难以碰撞: given x, finding y such that h(x) == h(y) is hard
- 应用: 签名, 验证, 文件去重, ...

LSH (locality-sensitive hashing)
- 输入扰动时输出大概率不变化
- 严格定义: 某种评分d及阈值r1, r2, 概率p1, p2下
  - d(X1, X2)<r1 时, P(h(X1) == h(X2)) > p1
  - d(X1, X2)>r2 时, P(h(X1) == h(X2)) < p2
- 为什么翻译为局部敏感哈希, 明明是局部变化不敏感哈希?

文本 / SimHash / 主要针对长文本, 解决网页抓取去重问题

我们业务上更需要针对短文本的编辑距离不敏感的simhash, 短文本编辑距离检索聚类

图像 / perceptual hashing / pHash / 相似图像检索

LSH"曲解"为机器学习的表征函数
- LSH=特征抽取/表征学习, 拥有相同关心目标特性的输入, 应有相似的特征向量
- 形式上的特征: 数据增强对抗习得
- 概念上的特征: 模型训练习得
- 模型训练: 大量输入习得LSH函数的过程 

# 距离检索手段

低维: 空间索引, GIS, 地图临近搜索, L1/L2度量

高维: 向量检索

## 树索引检索

R-Tree 针对低维空间

R=rectangle. 每个节点是一个空间闭包 (pos_min, pos_max), 从而可以范围索引确定
构建索引目标: 用最少的纸盒把房间中的点包住, 且尽可能的留白
和B-Tree结构类似

针对高维空间是否仍然有效 ??? 过于稀疏, 筛选性低

KD-Tree / k-dimensional binary tree

复习决策树 / decision-tree 生成手段, 每个维度当作一个特征分量, 从筛选性(方差)最高的分量开始切

## 图结构检索

- 构建KNN图, 如知道容许筛选最大距离则更好办可做成精确检索
- 遍历直到距离超过筛选阈值
- 计算实际距离二次过滤, 需基于距离特性: `d(x, z) <= d(x, y) + d(y, z)`

Q: 不同于地图寻路, 如何定位开始检索的节点?

## 量化手段

也可以理解为一种LSH

主要是为了确保量化前后计算的评分(这里严谨点, 不说度量)不发生较大变化, 因此需要先确定评分函数后针对性的量化 

- 二值化, 直接裁减干到1bit: `float32[256] > mean -> bit[256] = 64byte = uint64`
  - normalize过的参数, 认为mean=0, 均匀分布, 直接二级化
- 线性量化, 数值拟合: 基于单分量数值分布统计情况做压缩, 计算时需额外引入量化/反量化步骤
- 向量矩阵整体做PCA抽特征降维
- 多分量分组聚类, 减少存储开销
- 减少数据量就是最好的计算优化

对比模型参数压缩/量化: 模型压缩需要考虑矩阵计算便利性, 以及点乘结果的尽可能少扰动

# faiss

https://github.com/facebookresearch/faiss/wiki

> CODE HERE

首先不要瞧不起暴力/线性索引, 通过指令并行, mmap减少内存, 小场景还是可以满足诉求的, 参考目前搜索词推荐

# milvus

https://milvus.io/docs

底层基于faiss, 类似lucene和elasticsearch, 工具包还是单独数据库的区别

# 向量数据库

LLM风口后飞上天后的突然带火的热词

https://www.infoq.cn/article/saw52ys9ymut3c2zb9wp

本质上还是侧重高维向量数据快速检索问题

实现手段:

- 堆硬件, 上集群, 并行/分布计算: 向量度量计算任务非常容易并行, 数据拆分 + 维度拆分 后汇总过滤手段
- 指令并行, 单机计算上GPU加速计算
- 数据结构/算法优化/量化近似
- 常规数据库功能整合

ES/PostgreSQL+插件, 你也可以说它是向量数据库