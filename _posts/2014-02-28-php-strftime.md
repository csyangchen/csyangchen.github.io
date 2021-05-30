---
title: 从PHP的strftime实现想到的
---

## 缘由

在开发过程中, 利用strftime函数对含有类似%Y%m%d的字符串模板进行格式化的过程中, 发现字符串过长(超过1024)时, 后返回空字符串.
回头查查PHP手册, 发现也有一句话提到了这一限制. 为什么呢?

## 源码分析

PHP strftime本质上是对`time.h`的`strftime`的封装:

- PHP定义: `string strftime(string format [, int timestamp]);`
- C定义: `size_t strftime(char *s, size_t max, const char *format, const struct tm *tm);`

看一下代码实现:
 
    // ...
    int                  max_reallocs = 5;
    size_t               buf_len = 256, real_len;
    // ...
    buf = (char *) emalloc(buf_len);
    while ((real_len=strftime(buf, buf_len, format, &ta))==buf_len || real_len==0) {
        buf_len *= 2;
        buf = (char *) erealloc(buf, buf_len);
        if (!--max_reallocs) {
            break;
        }
    }
    // ...

可以看到, 初始返回内存大小为256字节, 对于绝大部分的strftime的应用场景是足够了. 同时作者考虑到了buf不够的情形, 尝试做了倍增的内存分配策略. 但是超过最大重新分配次数4后, 放弃了内存倍增的重试策略, 这就导致当字符串长度超过1024(=4*256)时, 就直接返回空串.
实现代码里面没有看到对于这种策略的解释.

## 想法

- 接口设计要能够区分正常和异常情况. PHP很多API没有办法做到这一点, 导致很多潜伏的BUG不能捕获.
- 避免magic number. 涉及到策略的时候, 需要有文档和注释来阐释理由, 为什么不允许按照实际长度分配大小256, 为什么5次重试, 不能够凭借感觉来假定, 而是应当充分论证; 或者通过宏或者配置的方式来做到可配置化.
- 争取简洁. 越多行的代码必然引入越多的BUG. 脚本语言的一大优势在于把一些底层API进行了抽象, 变得更加好用. 但是引入新的封装, 必然会导致引入新的BUG和不确定性. PHP strftime的实现代码长度超过了100行, 从PHP的BUG跟踪系统来看, 这个接口已经暴露了不少问题, 所以对于在做封装组件的时候尽量地"薄", 尽量保持原有语义, 不要自作聪明地添加逻辑.
