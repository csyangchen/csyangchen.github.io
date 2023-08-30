---
title: 数据压缩及模型量化
---

compression / bit reduction

- lossless 无损 / 数据压缩 / 模型tokenization过程 
- lossy 有损 / 视频, 音频 / 模型训练过程

考量: 压缩比 / 压缩速度 / 解码速度 / 数据失真 (lossy)

机器学习

# 压缩过程

基于词典的构建办法

- 基于数据, 生成词典
- 词典编码
- 数据基于词典编码重写

词典大小 + 编码后数据 >> 原始数据 才值得

词典/编码表 = 领域知识, 可以随数据传输, 也可以认为是传输双方前都明晰的预信息

数据分布假设: 生成/训练时习得的分布和后续应用的分布需一致, 压缩问题不用考虑, 就是要过拟合, 模型问题需考虑.

# 编码视角

已经给定了词典以及对应词频

编码长度和出现频次负相关

观察: 越是常用词, 越是短语

熵 / H(X): 最优编码的平均输出位宽 (香农第一定理: 无损压缩输出位宽不能低于熵)

哈夫曼(huffman)码: 最优前缀编码 (Kraft不等式)

- 前缀编码 / prefix code: 变长编码, 不会是其他的前缀, 一位一位读, 只要在字典中即返回
  - 流式解析, 解析时保持当前编码表匹配位即可 
- 定长编码: 固定宽度切割后查找, 可并行
  - 均长=log(N), 同分布时最优编码
  - 对于数据库列编码还挺有用的, 快速定位到第几行的数据

> DEMO TIME

其他编码: 算数编码, 直接编码为一个浮点数, 可理解为词频的CDF数值

entropy encoding

编码理论, 主要考虑通信带宽/纠错等相关问题, 不光考虑最小数据传输

通讯/带宽面向比特(bit), 计算/数据面向字节(byte)

# 最优词典构建

编码时已知词典加词频, 如何构造词典?

n-gram的所有可行分割后, 找最优编码表

> Q: 100层楼梯, 一次迈1~N步, 一共多少中迈法?

所有分法中, 找最小词典大小用于定长编码, 或最小H(X)

> DEMO TIME

计算上一般不可行, 如何解决: 分块之, 贪心之

# 文本可见的数据编码方式 / binary2text

这里提一嘴的目的是, 编码目的不一定是压缩, 也可能是为了表达, 或者冗余纠错

- hex / base32: 2**4, `[0-9a-f]`, 刚好两倍字节定宽, 1字节编码为2字符, 浪费50%, 简单明确
- base64: 2**6, `[0-9a-zA-Z]`+两个符号+等号填空, 3字节编码为4字符, 浪费25%
  - 两个符号: `+/`或`-_`, 看场景绕过, url_safe
  - 0~2个等号, 用于补到4的倍数, 其实可以不用
- base62 避免烦人的两个符号问题
- base58 避免形近字符0OIi
- base85 `84**5 < 256**4 < 85**5`, 5字符表达4字节, 浪费20%
- `101**6 < 256**5 < 102**6` 为什么没有base101编码? 可能ascii里面安全能用的字符不够101个?

# 数据压缩算法

方法
- dictionary method: 基于词典替换
- static method: 分析全数据, 构建词典, 然后再编码
  - 相当于先传词典, 再传对于词典引用
  - two-pass method
- adaptive method: 扫一遍, 回看一段历史数据, 数据即词典
  - one-pass method

# 压缩算法/格式

- LZ77 / LZ1
  - 重复序列消除, 滑窗压缩
  - 往前看一段, 滑窗内见过的重复序列标记替换: abcdabcdabcd -> abcd,(0,4),(0,3),d
  - 滑窗 = 词典
  - 窗口大小决定了压缩比, 压缩速率
  - 利用数据的局部性, 一般一个文章或一个段落针对一个问题展开, 重复短语反复出现
- LZ78 / LZ2
  - 单独构建词典
  - 找目前词典里面的最优前缀匹配, 然后纳入词典
  - 快于LZ77, 但是词典大小不可控
- LZW : 基于LZ2
  - 找不到的当作新词, 而不是续上
- LZSS: LZ77, 标记后长度不值得的时候不做
- DEFLATE = LZSS + Huffman (用于编码子序列及位置偏移标记)
  - gzip
- LZ3 ???
- [LZ4](https://github.com/lz4/lz4) 注重速度
- LZO: 块压缩, 注重速度以及内存开销
- LZMA
  - *.xz & LZMA2
  - *.7z & 7-Zip
- [snappy](https://github.com/google/snappy) by google
- [zstd](https://github.com/facebook/zstd) by facebook

其他方法
- BWT (Burrows–Wheeler transform): 文本变换为跟容易压缩的表达
- BPE (Byte pair encoding) / 多见于tokenization

# 文件格式

- 文本/通用字节压缩=一维
- 数据库字段=同文本
- 图像: 二维
- 视频: 三维

# 数据库字段压缩手段

列式存储数据库: 减少数据存储量, 此外通过减少IO优化查询速度 (因为IO远慢于解码)

- 低基数字段: 字典编码 / 枚举型
- RLE / Run-length encoding
  - 针对排序字段
  - AAABBC -> A3B2C ...
- delta encoding / 针对单调数值序列, 如时间戳
  - 123456,123457,123457,...
  - 123456,(123457,2),...
  - 123456,(+1,2),...
  - RLE组合使用
- varint / 变长数值型
  - 针对数值集中分布在较小区间, 如收入, 大部分人没几个钱
  - 同utf8编码形式
  - zigzag, 考虑负数情况的边长数值编码

数据块压缩, 同通用压缩方法

# 图像/视频压缩

图像 = 像素(色彩) * 长 * 宽

色彩
- 1bit 黑白世界 
- 8bit 灰度
- 8bit 彩色 256 种颜色
- 24bit=256*3 / RGB
- 32bit RGBA / alpha 通道

色彩表达
- RGB (red / green / blue) 三原色 / 计算机行业
- YCC (luma / 亮度 + blue difference chorma / 蓝移色度 + red-difference chroma / 红移色度)
  - RGB 可等价变化
  - 人眼对于Y值亮度变化不太敏感, 利用该弱点压缩色彩信息
- CMYK (cyan / magenta / yellow / black) 彩色印刷行业

图像压缩算法
- 颜色字典: 颜色最短编码
- 颜色量化: 消除近似色彩, 进一步减少字典大小
- run-length encoding 之于图像: 色块 (color, xmin, ymin, xmax, ymax) / 区域多边形 ???
- run-length encoding 之于视频: 不同帧之间找固定或者缓慢移动的色块, 动量 (motion vector)
- 色块/形状复用: Ctrl-C + Ctrl-V
- DCT: discrete cosine transform
  - 空域/时域信号变频域信号
  - MDCT / M for modified / 常用于音频
- FT / fourier transform / 傅里叶变换 / 三角函数组合拟合函数 / 平稳信号
- WT / wavlet transform / 小波变换 / 复数域, 频域+时域信号, 含FT 

常见图像/视频/音频格式
- GIF (Graphics Interchange Format)
  - LZW
- BMP: bitmap from Microsoft
  - 256位图 / 16位图 / ...
- PNG (Portable Network Graphics)
  - DEFLATE
- JPEG (Joint Photographic Experts Group)
  - DCT
- JPEG 2000 ??? 好像实际应用没见到过
  - WT
- MPEG: Moving Picture Experts Group
  - the generic coding of moving pictures and associated audio information
  - MPEG-2: h262
  - MP3: MPEG-1 Audio Layer 3
    - MDCT + FFT
  - AAC / advanced audio coding / MPEG-2 Part 7 / MPEG-4, MP3的后继者
    - MDCT only, 对比MP3更高压缩效率
  - MP4: MPEG-4 Part 14
    - originate from QuickTime by Apple 
    - 不光存储视频音频, 也可以保存字幕, 图像等
- h264 / AVC (Advanced Video Coding) / MPEG-4 Part 10 / 目前最常见 
- h265 / HEVC (High Efficiency Video Coding) / MPEG-H
  - HEIF: High Efficiency Image File
  - HEVC: High-Efficiency Image Container / HEVC in HEIF
  - 格式的演化是缓慢的, 13年推出, 然而, 23年了, windows默认不带hevc编码器放不了, 导致我们所有视频数据都要转一遍, 哭
  - 目前我们业务统计数据上占比逐步升高, 但也不到15%的水平
- VP9 by google / 也是默认打不开, 需要转码的
- KPG: Kai's Power Goo (PS的一个插件???) / 快手直播等使用, 导致我们要转一遍

# 拟合问题 / 模型学习

拟合问题
- 结构: `f(x)`
- 观测数据 ~ `f(x) + rnd`
  - rnd: 认为无关的, 独立同分布的观测误差/扰动
- 参数学习 `f(p, x)`
  - p可以是具体函数的参数 (从而尽量可推解析解)
  - p也可以是一族函数的屏蔽/激活门 (NP)

f / 先验编码表

压缩 / 模型学习 的信念是相信数据一定基于一段代码生成出来的, 逆向的过程

# 编码器-解码器结构 模型视角

- 压缩场景: 编码器, 解码器 是对等的, 确定的
- 编码器: 输入语种的压缩过程
- 解码器: 输入语种的解压过程
- 编码器输出数据: 压缩后的信息, 可再转用它途
- 由于生成过程引入了随机性, 解码结果不是确定的

存在合理性 / 信念: 
- 输入数据(语言/图像)是极度冗余的
- 在给定的小场景下, 各种简称是不会导致歧义的

# 模型压缩手段

数据压缩, 通过增加计算减少存储开销, 模型压缩主要目的一般是计算加速

有损压缩

单减少存储大小角度, 常规压缩办法均可, 尤其对于结构确定, 模型全是参数数值场景, 不过模型参数存储减少本身无太大意义

手段
- 特征选择, 从输入上就只用有显著性的特征维度训练, 舍弃掉提点有限的特征维度
- 剪枝 / Pruning:
  - 直接舍弃部分结构
  - 简化模型大小 
  - 避免过拟合
- 知识蒸馏 / KD / knowledge distillation
  - 先训练出老师模型
  - 确定参数更少的学生模型结构, 一般窄而深, 专攻一处?
  - 准备训练数据同时跑老师/学生模型, 计算损失回传, 更新学生模型参数
  - 在最终分类层损失学习, 也可在中间输出层学习参数损失 (感知迁移)
  - 为什么不直接训练学生模型?
    - 老师模型可能是预训练模型+微调, 拿不到完整训练数据 OR 从数据训练起成本太高
    - 老师模型泛化性好, 简单模型直接怼低质量数据学, 容易走火入魔学偏了?
- 结构/参数共享: 类比代码块复用, 类比LZ复用见过序列
- 量化 / quantization
  - 模型结构不变, 参数数值裁剪到低位宽
  - float32 映射到 int8: 4倍内存减少, 2~3倍计算速度提升
  - 量化后参数更容易压缩存储
  - 主要目的减少计算量
- layer norm / batch norm 算不算辅助压缩手段 ???
  - normalize后的参数分布集中, 容易压缩
  - 参数分布越平均/uniform, 越容易量化

Quantization:
- 高范围连续数值映射到低范围离散数值过程
- 如模拟信号转数字信号

量化拆解
- 逐层量化, 同向量量化 / per layer
- 输入逐通道量化 / per channel

按照训练时是否感知量化区分
- QAT: Quantization Aware Training 训练时通过约束参数分布, 可以做到更低精度损失
- PTQ: Post Training Quantization

> TODO PyTorch DEMO

# 代码压缩

重构: 压缩, 稳定逻辑流程提取固化复用, 减少代码量, 识别容易变更处, 识别业务模式, 以期修改更灵活, 泛化性更好, 以适应新的功能需求. 领域特化的代码库.

# Reference

- https://en.wikipedia.org/wiki/Data_compression
- https://www.youtube.com/playlist?list=PLm_MSClsnwm-Foi9rVF0oY2LdldiL7TAK