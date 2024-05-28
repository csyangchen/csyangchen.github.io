---
title: 序列化笔记
---

# 文本格式

JSON 流行度最高. Web时代的 de facto 的序列化标准.
缺点在于没有内置的注释之类语法.
有 json schema 之类的格式定义和检查工具.
由于和Javascript交集较多, 实践中有一些需要明确的边角地方, 比如说int64的问题, null的问题, 等等.

XML 最严谨, 方便扩展, 但是公认的难用. 上古遗兽, 可惜日常还是会经常打交道, 尤其 Java 生态圈里.

YAML, TOML 主要作为配置文件格式使用.

# 二进制序列化格式

文本格式优点在于直观可读, 但是缺点在于序列化的大小比较大.
另外解析的时候, 一般涉及到上下文解析文法, 序列化/解析开销比较高.

说明一下: 在不考虑解析效率的情况下, 文本格式+压缩算法, 已经基本够好, 不用特别优化.

二进制格式相对而言, 空间利用更加节省, 序列化/解析方式更加面向计算机, 性能更加优化.

总之优点: **省空间, 速度快**

## BSON

BSON主要为Mongo服务的, 没有接触过其他单独使用的场景.
其序列化方式比较简单, 没有特别针对节省序列化大小的做法.

数值类型固定长度的优点在于可以 **in-place update**.
比如说更新一个int32字段, 只要更新所在的4个字节即可, 不用重新更新整个消息.
而对于变长方式序列化的数值字段, 除非前后值序列化长度相同, 否则需要重排.

此外, 一些数据库产品, 支持JSON类型字段, 但实现上做了一定的优化. (e.g. jsonb)

## MessagePack

- <https://github.com/msgpack/msgpack/blob/master/spec.md>

MessagePack 用至少一个字节表示字段类型及长度信息. 从而可以用更少的字节表示数值.

MessagePack 的优点在于自解释, 不需要额外的schema帮助解析, 就能够直接还原出完整的字段名和类型.
缺点是序列化时需要原样保存字段名, 使用中比较严重的情况是绝大部分空间都被字段名所占据. (也许在文件存储时候, 可以通过文件压缩, 将字段名枚举化, 从而进一步优化序列化大小?)
不过这也是不依赖外部schema (即信息论上所谓的互信息), 能够做到的最省情况了.

比较适合的场景是后端通讯, 在不能借助IDL的情况下交换数据. 保持了类似JSON的结构调整灵活性, 也节省了一些空间.

# Protobuf (a.k.a Protocol Buffers)

<https://developers.google.com/protocol-buffers/docs/encoding>

对于数值类型使用varint的列化方式 (类比UTF8).
对于字段不用字段名标记, 而是采用字段号 (field number / tagging).

此外, 字段类型+字段号 通常可以一个字节搞定:

	(field_number << 3) | wire_type

可以看出, 3位表示类型, 因此支持最多7种类型(实际在用4种). 对于小于 2^(8-3-1) - 1 = 15 的字段号, 用一个byte就可以解决问题.

对于字段类型是非常节省. 举例来说, 对于sint64/float64字段是同类型, 需要通过schema来确定具体解析方式.

Protobuf 非常适合通讯消息的序列化. 配合gRPC使用.

缺点在于数据处理生态圈方面支持比较有限.

# Thrift

和 Protobuf 类似, 不多介绍.
个人觉得文档不好, 而且主要卖点在于 RPC, 随着gRPC的流行, 行将就木.

# Avro

<https://avro.apache.org/docs/1.8.1/spec.html>

序列化不写类型/字段标记信息. 基于额外schema帮助解析.

相对于proto的缺点在于, 由于需要按照schema来解析, 不可以省略零值字段, 至少要占一位字节.
因此, 对于很稀疏的消息, protobuf生成长度很小.

不过好处在于, 能够确定的清楚每条消息解析的结束, 从而方便进行流消息解析, 而 Protobuf 或者 MessagePack 就不能很好的流解析, 需要借助外部的消息分隔机制实现.

此外, avro本身目标是此外定义了作为对于面向文件的存储格式, 支持文件块切割, 并且支持文件块层面的压缩, 以方便并行处理.

至于schema演化问题. 只能追加字段(append only), 已有的字段永远在那里了. 这个是个人觉得不是很方便的一点.

至于 Avro RPC, 呵呵.

# Cap'n Proto & FlatBuffers

- <https://capnproto.org/encoding.html>
- <http://google.github.io/flatbuffers/>
- <https://capnproto.org/news/2014-06-17-capnproto-flatbuffers-sbe.html>

为了避免解析的开销, 走的是懒解析(lazy deserialization)方式.

# 列式存储

字段按列存储, 相同类型, 另外同字段取值服从一定的统计学分布, 从而可以采用更高效的压缩手段压榨存储空间.

另外, 对于个别字段的读取, 可以极大地减少IO操作.

涉及到数据库查询方面, 预计算统计指标, 从而方便做查询谓词下推(predicate pushdown), 提前过滤掉不必要的读取.

基本思路是, 按行切割成块, 每块按列存储.

## ORC

<https://cwiki.apache.org/confluence/display/Hive/LanguageManual+ORC>

## Parquet

- <https://parquet.apache.org/documentation/latest/>
- <https://parquet.apache.org/presentations/>

# Reference

- <https://martin.kleppmann.com/2012/12/05/schema-evolution-in-avro-protocol-buffers-thrift.html>
