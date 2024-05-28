---
title: Tokenize与新词发现
---

# 引子

问题1: 为什么大语言模型做不好反转单词, 以及数数类的简单任务?

(gpt-35-turbo测试结果)

```
> Take the letters in lollipop and reverse them
The reversed letters of "lollipop" are "pilpolol".
> How many characters are there in word abacadabra?
There are 11 characters in the word "abacadabra"
> How many characters are there in this sentence?
There are 35 characters in "How many characters are there in this sentence?" including spaces.
> How many words are there in this sentence?
There are nine words in this sentence.
> How many spaces are there in this sentence?
There are six spaces in this sentence.
> How many 'a' are there in this sentence?
There are 3 occurrences of the letter 'a' in the sentence.
```

问题2: 语言模型都按照问答文本的token计费, 如何测算?

https://platform.openai.com/tokenizer

English: 1 token ~ 3/4 word OR 4 characters

# tokenization

目的
- 数据压缩, 以加速训练及推断
- 期望词元相对单字有更丰富的表征, 从而简化对于模型结构复杂性的需求

变换过程 (embedding layer): 字表宽x文本长 -> 词表宽x编码长

考量点:
- (长) 编码长度
  - 对于Transformer结构来说, quadratic cost of self-attention
  - 对于生成模型, 输出时候要一个一个吐出来, 自然希望编码序列长度尽可能短
  - NTP / next token prediction
- (宽) 词表大小
- 信息传递的丢失
  1. <unk>导致的信息丢失
  2. 人理解文本和编码后序列模型理解的"视差"

这里先针对英文展开讨论

word-level tokenization / 空格+符号分词, 生成词表过大

过大词表问题: 模型输入内存空间太大, 计算复杂度上升, 词于词之间的关联表征信息丢失了, 如英文里面单复数, 时态等

character-level tokenization / 词表=字表, 文本长度即编码长度

过小词表问题: 对模型来说学习太困难了, 自己独立再学习总结出来组成词的概念. 空格, 符号等本身就是对于人类阅读时的注意力标号信息.

英文词有时态/词根等领域知识 (语法), 可以提前抽取出来, 如-ization本身表明的名词化, -ed / -ing表明时态, -s表明单复数, -ly表明状态等.
这些单独抽出来作为词元, 能够忠实保留元信息.

subword tokenization / 折中办法: 对于词进一步分割以减少词表大小:
- tokenization / civilization / colonization -> token / civil / colon / ization

# tokenization训练

## BPE (Byte Pair Encoding) for GPT

- 对训练文本简单预处理 (如基于空格符号分割), 统计出一个词频表
- 词表从基础字表出发, 迭代合并: 对词频表中统计高频子序列 (2-gram), 最高子序列单独成词, 加入词表, 从而减少整体编码长度 (Q: by how much?)

例子: "cat hat bat" -> {cat: 1, hat: 1, bat: 1} -> {c: 1, h: 1, b: 1, at: 3}

词表大小 = 字表大小+合并次数
- GPT: 40478 = 478 + 40000
- GPT2: 50257 = 257 + 50000
  - byte level BPE: 字节角度看字表, 从而无损编码
  - 257 = 256 + 结束符

> DEMO TIME

GPT词表观察:

- 由于没有对于空格预处理, 很多词会有带空格不带空格的两个token, 如"public" / " public", " Hello world" != "Hello world". 如确保词无空格, 会是怎样的结果?
- 对于单词的分割和人类理解并不一致, "w|alking t|alking st|alking"

## WordPiece for BERT

流程同BPE, 但是合并标准不是看频次, 而是看共现概率

`argmax(freq(ab))` VS `argmax(freq(ab)/freq(a)*freq(b))`

由于编码时对空格会预处理掉, **因此**词表里面需要区分后缀子词 `ing/##ing` 

问题:
1. 上面的"因此"如何理解?
2. BERT编码能还原回原文本么?
3. 如何看待这里BERT和GPT的编码选择区别?
   - 一个是encoder-only, 一个是encoder-decoder模式, 自然需要考虑可还原性

## 最优tokenization?

上述是两阶段的贪心算法, 先长序列切成长度可控的短序列, 然后每次取一个最大的.

在给定词表大小限定条件下, 最优的基于词表的tokenization算法? 对于每个样本的所有切法, 找到导致整体编码长度最短词表.

和通用压缩问题区别: 压缩还需要考虑每个token编码后长度, 这里不用考虑, 等长对待.

# tokenization推断及优化

推断目标: 对于所有词表切法中, 返回最短的 (DP算法, 同有权重词表分词, 返回权重和最大的)

推断的加速手段? 用rust/上并行/针对编码词表规则的特化/牺牲一点结果最优性以优化速度

最短是否等价于扫一遍当前位置找最长的 (longest-match-first strategy)? 否, 但是这种速度最快, 实际应用时值得考虑, 如前向后向两次取较短者, 先切割然后每段单独细分, 等.

正对BPE词表生成方式的特化: 对文本跑一遍合并过程更简单, 前提需要求合并路径词都得存下不能丢弃

https://github.com/openai/tiktoken/blob/main/tiktoken/_educational.py

针对一定会切开的地方, 如空格符号等, 提前分割后, 并行编码.

值得玩味的点:
- break even策略, 即相同最优结果不同编码方式, 对于结果影响?
- 对于BPE, 加不加前缀空格, 以及是否先自行空格切开再编码, 对于结果影响?

解码过程, 相对就很简单: 词表一个个找出来拼接即可

# 不做tokenization?

tokenization编码/解码(encode/decode)环节相当于人类和模型交互的翻译. 
对于LLM非常基础重要, tokenization方式相当于提前纳入了人为假设/偏见, 严重限制了LLM的学习能力, 值得各方面针对这个角度的研究.

文本本身有非常高的信号冗余, tokenization被认为是合理的. 文本的tokenization是否应该和人类感知文本对齐? 如何理解人类是接受文本信号的?

图像/音频的tokenization? 
图像的tokenization, 由于2维关系, 需要分割打码加上位置信息后传入模型.
音频的tokenization, 也是需要先离散化, 这个离散化过程是否限制了信号的表达?

[苦涩的教训](http://www.incompleteideas.net/IncIdeas/BitterLesson.html): 应尽量减少人为干预

完全基于字节(256)或者位(2)信号训练? 模型自行学习编码器/解码器 

主要还是不编码的数据及计算膨胀问题, 算力足够, 相信会有更简单的编码方案的模型.

# 中文tokenization的粒度问题

字表太大, 决策问题
- 完全基于单字, 为了词表大小, 需舍弃罕见字, 有损
- BPE方式罕见字可能被拆成多个token
- "饕餮"/"魑魅魍魉"等罕见词, 不太可能单独字方式出现, 可以入词表, 不过意义不大

是否应该扩充词表以减少编码长度?
- 常见词扩充, 又回到了监督分词的视角, 纳入了太多先验知识
- 非监督方式成词, 容易和人类标注数据边界对不齐

中文已经足够简练, 博大精深, 就不要再成词编码?

国产模型貌似还是普遍会对中文进行提前分词处理

https://www.volcengine.com/docs/82379/1099320

# 传统文本特征抽取手段回顾

- 词级别清洗
- 中文而言, 先分词
- 对于词级别做n-gram拓充
- 掐头去尾, 去掉高频词, 去掉低频词
- 丢掉了全局文本序列信息, 词袋模型, 局部信息靠n-gram保留下来
- 或临近词做词向量学习

要学习的特征维度低

# 中文分词训练回顾

tokenization: 非监督训练, 是确定性的算法过程

分词: 有标号文本的监督训练

- 准备分词文本语料
- 统计词频, 生成词表, 推断时取最大共现词频
  - 完全基于统计信息, 并不考虑文本语义信息
- (HMM做新词发现) 对词表的字进一步统计得到状态转移以及表征概率
  - 词性状态: BI (首字/非首字), 再拓充SBIE (单字/首字/非首字/尾字)
  - 例子: 名字预测器
    - 见多了"陈X", "陈Y", 作为B的概率较高
    - 字扩充: "X国强", "X建国", "X翠花", 作为I的概率较高
  - 本质上是把成不了词的字强行组合到一起, 效果并不好, 回顾"中出"的例子
- 上更复杂的模型(MEMM/CRF)做词性分类推测任务
- 上规则提取等
  - XXX品牌特卖日, 来XXX官方旗舰店, XXX的人有福了, ...

难点: 样本质量及质量难题
- 分词标注, 按照不同下游任务, 标准很不同: "广州市动物园, 张翠花"
- 大模型要大数据, 难以做成自学习方式

# 中文新词发现

非监督分词=tokenization

新词发现: 已有词表, 找出文本中不在词表的有意义词 (OOV)

问题等价, 唯一区别在于是否有先验词表

基于词表/字表逐步进一步合并, 拓充词表

思路其实同上述tokenization训练, 不断合并

1. 对文本n-gram切, 然后基于词频, 或者进一步TF-IDF等卡阈值提取, 如在词表忽略, 容易提出一些不知所谓的词
2. 算共现概率 (AKA 邻字信息熵) 卡阈值提取

> DEMO TIME

# 总结

tokenization是为了模型理解, 结果对模型输入负责; 分词一般是为了搜索场景, 结果对人(这个模型)容易理解负责.
tokenization为了压缩, 目的输出最短的; 分词是概率上猜一个可能性最高的.
切出来的token对人类来说不带有意义, 分词切出来的结果对人类可以理解有意义的.

人类时很容易按照目的重新自适应tokenize, 比如"How many characters are there in word abacadabra"问题, 重新把关注点从词义细化到数字符.
对于模型而言, 最原始的表征已经丢掉了, 只能靠模型不断学记忆下来.

模型如何做到正确的反转单词? 需理解语义并且记住每个token的对应反转token, 这是很难非监督方式习得的, 除非定向生成一大波训练样本.

# Reference

- https://github.com/huggingface/tokenizers
- https://github.com/openai/tiktoken
- https://github.com/google/sentencepiece
- https://huggingface.co/docs/transformers/tokenizer_summary
- https://huggingface.co/course/chapter6/1
- http://www.matrix67.com/blog/archives/5044
- https://zhuanlan.zhihu.com/p/67475895
- https://spaces.ac.cn/archives/3913/comment-page-1
