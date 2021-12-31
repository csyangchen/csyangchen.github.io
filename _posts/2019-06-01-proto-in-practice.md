---
title: protobuf实践
---

业务上统一用protobuf来定义数据交换. 实践中的一些记录.

生产中用[prototool](https://github.com/uber/prototool)做检查构建流程.

# JSON相关

对外, 尤其是web接口, 一般还是以JSON形式交互, 一些注意点.

[JSON映射关系](https://developers.google.com/protocol-buffers/docs/proto3#json)

从JSON转的一些选项:

- marshal / Marshaler
  - use_integers_for_enums / EnumsAsInts 枚举值用数值, 建议true
  - preserving_proto_field_name / OrigName 保留proto定义字段名, 一般true
  - including_default_value_fields / EmitDefaults 空字段也输出, 一般节约空间false
- unmarshal / Unmarshaler
  - ignore_unknown_fields / AllowUnknownFields 忽略未知字段, 为了向后兼容, 建议true

需要注意一些外部交互的过程中, 有些不能很好的解析null等字段, 或者对于即便空字段也是有存在要求, 要么在前置沟通中明确下来, 否则就的做一些恶心的特殊处理.

# 数据类型

尽量使用枚举便于有效性校验, 但是统一将枚举按照integer处理, 保留枚举名的变更灵活性.

由于javascript不能原生支持 int64. int64 json 里面是string, 设计上尽量避免int64数据类型.

由于java/avro不支持unsigned, 设计上避免unsigned类型.

谨慎使用预定义的数据类型 (<https://developers.google.com/protocol-buffers/docs/reference/google.protobuf>)
现在我们仅允许用`google.protobuf.Struct`做一些map的需求, 如记录HTTP请求/响应头等信息.

# 枚举约束

通过枚举类型来约束可能的值, 以及方便各端避免magic number.

实践中不方便的点: proto3要求必须有0值枚举; 且枚举名要全局唯一, 不能够重复, 导致枚举命名非常罗嗦, 而且不能很方便的生成枚举到文本的双向映射.
局限了我们实际使用中的范畴.

> Note that enum values use C++ scoping rules, meaning that enum values are siblings of their type, not children of it.

# 数据约束

proto3已经不支持required关键字. 实际生产中对于字段是否存在/合规还是挺重要的.
用字段注解工具生成对应的数据有效性约束逻辑.

# 数据演化

单值变列表(repeated)调整是向前兼容的, 这个是我们实践过程中非常有用的点.
因为保不齐某个字段就从单值变多值了.

不同于avro, 解析是按照tag来做, 很容易用做错误的消息解析还不报错.
使用中需要特别注意schema的管理, 以及配合消息约束校验来挡.

# protoc插件扩展

protoc-gen-plugin机制非常完善.
结合一些业务需求, 我们做一些protoc插件开发, 如基于proto生成消息文档, 生成对应的数据库表定义, 生成avro定义等.

# Reference

- <https://developers.google.com/protocol-buffers/docs/proto3>