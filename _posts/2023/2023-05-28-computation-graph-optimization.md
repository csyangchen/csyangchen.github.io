---
title: 计算图优化
---

模型导出后做推断目的

- 最小依赖
  - 不想装pytorch上G的依赖
  - 具体开发SDK/语言无关
  - PY代码训练, JAVA/GO等代码推断的可能场景
- 性能优化
  - 资源限制 (内存等资源/异构的推断运行环境等)

# 程序编译执行过程

- frontend / "前端" / 代码
  - Python
  - SQL
  - Java / Groovy / Scala / ...
  - ...
- IR (intermediate representation)
  - JVM / CPython / Lua 等 ... 虚拟机字节码 / bytecode
  - LLVM
  - ONNX
  - ...
- backend / "后端" / 指令集
  - X86 / ARM / M1 / TPU / GPU / ...
  - 不同硬件适配优化

计算机就是一层一层的抽象, 一层包一层.
越上层越简洁, 但是性能越差.
从上到下的全局理解很难, 但是对于实际性能优化很重要.

DEMO HERE

Python程序优化套路: Python写意图, C改写实现

> Python for clarity, C for performance

最简单的CPU后端:
- 计算图逻辑翻译为C++代码后执行, C++代码编译器再负责优化实现
- 再进一步, 写点编译优化注解

编译为C的方式
- CPython扩展开发 (Cython / CFFI / pybind11 / ...)
  - AOT (Ahead of Time) 编译
- Numba
  - JIT (Just in Time) 方式编译
  - 针对numpy, 翻译目标为LLVM
  - inlining, loop fusion, ...
  - 注意: 导致的额外依赖特别多, 以及会导致显著的额外内存开销, 业务上尽量绕开和这个打交道的 !!!
- ...

# 计算图

- 张量 / tensor
  - 数据类型/精度
  - 维度信息
- 算子 / operator
  - 输入输出张量的函数
  - https://onnx.ai/onnx/operators/index.html

模型 = 结构 + 参数
- 结构 = 计算图
- 参数 = 计算图中的常量张量参数

DAG

算法模型=计算图

不涉及IO, 不产生副作用, 一定固定步数执行完成输出的, 纯函数

- 计算图捕获: frontend -> IR
- 计算图加速: IR -> backend

# 静态图 VS 动态图

静态图
- 执行前需要跑一下编译过程 `keras.model.compile`
- 类比编译型语言(C/Java/Go/...)

动态图
- Eager Execution 模式
- 单算子会在计算图中立即执行得到结果, 各算子/函数视情况单独优化实现
- 可以很好的和Python其他代码逻辑交互, 灵活便于调试
- 类比解释型语言(Python/Lua/...)

主观感受: 是否支持动态尺寸输入

殊途同归:

- 2019 Tensorflow 2.0 优化动态图特性, 默认启用 Eager Execution
- 2023 PyTorch 2.0 静态图编译优化性能

# torch.jit / TorchScript IR

PyTorch模型代码的IR形式, 运行时可不依赖Python环境, 但是依赖一个较大的SDK (LibTorch)

直接用pickle做序列化格式

基本上Python语法的子集: https://pytorch.org/docs/stable/jit_language_reference.html

torch.jit.script

静态代码解析提取, PY代码翻译为计算图, 保留了动态控制分支流

torch.jit.tracing

需要提供样本输入, 反射机制跟踪计算过程, 只看到实际执行的路线, 参数常量化, 抹掉动态控制流, 执行性能更好

@torch.jit.script 手动声明需要导出/忽略或者包装的方法

DEMO

# PyTorch 2.0

TorchScript的问题: 需要代码编写者做特别处理, 额外的心智负担

主要卖点是提速

- TorchDynamo / 新的计算图捕获方式
  - 基于Python Frame的计算图捕获, 更快, 成功率更高
  - https://pytorch.org/docs/2.0/dynamo/index.html
- TorchInductor / 新的计算图编译
  - GPU上翻译为[Triton](https://github.com/openai/triton)语言 (CUDA再包一层)
  - 只支持Volta/Ampere架构, 针对服务器显卡优化
- AOTAutograd / 自动微分引擎
  - 捕获梯度回传过程编译加速
- PrimTorch / 明确核心算子
  - 2000+ 算子 -> 250+ 基本算子
  - 便于不同的后端实现

`torch.compile` 默认情况尽可能把可以不用Python执行的环节抠出来编译执行, fullgraph全部导出为计算图, 但是对于代码写法有严格约束

怕ONNX抢饭碗???

`torch.compile`主观对比感受 (BERT分类任务)

4090 上一定提升
2080 上负优化

GPU优化针对的"高端"服务器显卡, "低端"RTX游戏卡似乎和感知不大

目前局限: 不支持PY3.11 / 不支持Window

# ONNX / Open Neural Network Exchange

![](https://techcommunity.microsoft.com/t5/image/serverpage/image-id/192470iAE331AFD83BA4079/image-size/medium?v=v2&px=400)

ONNX: 框架无关的IR, 或者说数据标准/协议

微软撑腰的项目

- 计算图数据结构定义: [Protobuf格式](https://github.com/onnx/onnx/blob/main/onnx/onnx.in.proto)
- [算子定义](https://onnx.ai/onnx/operators/index.html)
  - ai.onnx 基本算子
  - ai.onnx.ml 一些传统机器学习方法算子, 例如 TreeEnsembleClassifier
  - ai.onnx.preview.training 训练相关加速算子 (新)

ONNX Runtime (ORT): 跨平台的ONNX模型推断(及训练)加速器

- onnx IR基本的定义读写相关
- onnxruntime CPU推断加速 (目前我们用的)
  - 依赖小: onnxruntime~6MB vs pytorch (主要是LibTorch)~183MB
- onnxruntime-xxx 特定硬件设备推断加速 (onnxruntime-gpu CUDA推断加速)
- onnxruntime-training 训练加速

计算图捕获: `torch.onnx.export`利用`torch.jit.trace`后导出ONNX文件

导出的计算图是未处理的 (除了常量折叠), 推断时根据执行环境对计算图优化

有针对模型结构的优化器

DEMO TIME

PyTorch模型 153QPS / BERT优化后ONNX 360QPS

## 动态尺寸 / dynamic axis

batch / 批量大小 / 一般推断场景单批就行了, 不必要动态batch

序列模型场景, 需要申明动态尺寸

动态尺寸会导致不能执行一些优化, 但是从性能上来说比补零定宽更值得

# 计算图优化

## 常量折叠 / Constant Folding

## 算子融合 / Fusion

加乘算子 / Matmul Add Fusion

- PyTorch层面算子融合 [torch.addmm](https://pytorch.org/docs/stable/generated/torch.addmm.html)
- GEMM (general matrix multiplication) 指令
- X86 FMA (Fused Multiply Add) 指令

BERT Embedding Layer Fusion

...

## 数据布局重排 / Layout optimization

NCHW for CNN

卷积计算转换为两矩阵相乘

## 并行计算

NOTE 并行 (parallelism) vs 并发 (concurrency) 区别

### 硬件指令执行层面并行

提升速度手段:
- 简化执行指令序列, 单指令多数据 / SIMD (single instruction multiple data)
- 可以潜在的对数据矢量计算 / vectorization

e.g. [AVX](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions)


### 单算子并行

CPU上是OpenMP编程, 映射到指令层面并行

```
def mul(a, b, n):
    #pragma omp parallel for
    for (i = 0; i < n; i++) {
        a[i] *= b[i]
    }
```

### 多算子并行 / 子图分解

计算图没有依存关系的部分可以同时计算

类比: 运筹学 / 调度任务安排

### 线上推断运行问题: OpenMP错误配置导致实际推断性能下降

容器化推断环境运行, 默认拿到的是宿主机器核数, 实际上限制了CPU数, 错误的安排线程数, 反而会导致性能下降

需手动基于容器配置感知修改OMP_NUM_THREADS, 或者改session_option

## 计算图训练优化

计算图加速不光对于推断(前向过程)有意义, 对于训练(+后向过程)同样意义重大

分布式训练 / 混合精度训练 / ...

- HuggingFace Accelerate 库
- [DeepSpeed](https://www.microsoft.com/en-us/research/project/deepspeed/) by Microsoft
- ...

推断/训练需求算力越来越大的今天, 关注计算图优化的意义: 小我: 努力省钱, 将本增效; 大我: 低碳排放, 保护地球 !

实践中训练最有效的优化措施: 提高数据读写IO (磁盘到内存, 内存到显存), 把GPU利用率打满, 把显卡烤熟后再考虑其他手段

# 努力编写可导出的模型代码

现状: 训练时torch逻辑, 推断时numpy逻辑, 写双份.

期望: 预处理/后处理尽可能打包到模型中, 避免逻辑同步维护及正确性校验工作, 确保训练推断一致; 以及能显著优化推断性能

要相信, 只要不涉及外部IO的, 都可以翻译为计算图逻辑; 导出的再挫, 也一定比手搓的PY代码要强

例子

- 图像预处理
  - DEMO
  - 直接套用`torchvision.transforms.*`
- 分类卡阈值输出
  - DEMO
- IoU and NMS
  - https://github.com/onnx/onnx/blob/main/docs/Operators.md#nonmaxsuppression
- 最大概率序列预测 (viterbi / CRF / ...)
  - `@torch.jit.script` 包一下FOR循环 / 否则tracing出来的是错误的结果 (参数长度变量当作常量了, 推断给时输出不超样本情况下还不报错)
  - https://github.com/onnx/onnx/blob/main/docs/Operators.md#Loop
- GPT结构自编码器文本生成加速 ???

https://onnxruntime.ai/docs/reference/operators/add-custom-op.html

程序优化指南
- make it work
- make it right
- make it fast

# 其他模型推断加速手段

- 模型压缩
- 批量推断
- 硬件加速器
  - TPU / FPGA / ASIC / AI芯片产业
  - 针对模型结构的加速器 / transformer编码器/解码器推断加速 / ...
- (最简单有用的) 业务角度观测优化 / 问题定义

# Reference

- https://onnx.ai/onnx/index.html
- https://onnxruntime.ai/docs/
- https://pytorch.org/get-started/pytorch-2.0/
- https://pytorch.org/docs/stable/jit.html
- https://pytorch.org/tutorials/intermediate/torch_compile_tutorial.html
- https://openmlsys.github.io/
- https://d2l.ai/chapter_computational-performance/index.html
- https://mlc.ai/zh/