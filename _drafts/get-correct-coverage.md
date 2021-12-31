




同一个package, 如果一个文件没有测试, 那么不会纳入统计. 

不同package


    sh -c 'go list -f "echo \"package {{.Name}}\" > {{.Dir}}/xxx_test.go" ./...'

# -coverpkg 的问题


不支持多个main

Reference:

https://github.com/golang/go/issues/27261
https://github.com/golang/go/issues/24570


# python

coverage run --source

__init__.py