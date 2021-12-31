---
title: protoc plugin 机制
---


proto 文件本身 用 proto 描述.

stdin CodeGeneratorRequest -> stdout: CodeGeneratorResponse  

因此不返回任何内容也是ok的

option: 

protoc-gen-{plugin_name}

{name}_... -> 

protoc ... --{plugin_name}_out={plugin_options}:{plugin_output_dir}

# protoc-gen-go Plugin

e.g.: gRPC

缺点: 需要代码层面引入.

# insertion point

TODO

# Reference

- https://raw.githubusercontent.com/golang/protobuf/master/protoc-gen-go/plugin/plugin.proto
- https://github.com/uber/prototool
- https://github.com/grpc-ecosystem/grpc-gateway/tree/master/protoc-gen-grpc-gateway
- https://github.com/grpc-ecosystem/grpc-gateway/tree/master/protoc-gen-swagger