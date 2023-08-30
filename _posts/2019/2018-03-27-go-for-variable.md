---
title: Golang for循环 变量使用注意 一则
tags: golang
---



今天开发的时候, 排查一个不能必现的BUG, 花了不少时间, 最终发现是对于基本语法理解不深刻导致的.
这里记录一下, 以博各位看官一乐.

注意点: for 循环里面, 变量是重复赋值的, 不要想当然的当作每次创建一个新的局部变量.
所以在 循环体 里面千万不能取引用.
类似的道理, 在 循环体里面创建 goroutine, 也一定要记得将参数拷贝带进去, 否则会绑定到循环最后复制变量.


    ws := make(map[string]io.Writer)
    for k, c := range m {
        // ERROR 最终都指向最后一个
        ws[k] = &Writer{c: &c} // 这里其实原来是 func (c *Conf) New() ... 不影响结果

        // OK 拷贝变量, 而不是指针引用
        w := &Writer{c: c}
        // OK 拷贝一份局部变量
        c2 := c
        w := &Writer{c: c2}

        // ERROR
        go func() {
            w := &Writer{c: c}
            w.Start()
        }

        // DO
        go func(c Conf) {
            w := &Writer{c: c}
            w.Start()
        }(c)
    }


其实最近也有看到相关的[文章](https://tonybai.com/2018/03/20/the-analysis-of-output-results-of-a-go-code-snippet/), 不过之前看了没有什么切身体会, 工作上遇到了才有深刻印象.

Go Spec 文档也曾对此做过[修订](https://github.com/golang/go/issues/7834).

类似的PHP的坑之前也[记录过](php-variable-reference-trap.html). 发誓以后各种语言都不再踩类似的坑了~

References

- <https://github.com/golang/go/issues/7834>
