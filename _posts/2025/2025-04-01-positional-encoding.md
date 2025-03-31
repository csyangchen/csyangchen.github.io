---
title: 理解位置编码
published: false
---

信息汇聚手段: CNN

CNN 空间信息 卷积核汇聚

RNN 时序计算, 天然一维信息, 只有当下的记忆 / Hidden State

Attention / Transformer 一次看之前全部, 但是没有位置(或时序)的概念, 因此需要增加额外位置编码, 嵌入到隐层空间维度中.

隐层维度 -> 隐空间维度. N维空间可以张出一个很高维的"近似"正交的空间出来.

Transformer for image: 图像切片然后打上位置标记当作一维序列数据

不要位置编码会有什么问题

怎样才是好的位置编码信息

固定的位置编码参数 -> 可学习的位置参数



https://spaces.ac.cn/archives/8130

用空间换

不同位置在特征空间中占有一席之地


