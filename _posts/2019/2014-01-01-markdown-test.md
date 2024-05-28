---
title: Markdown测试页
published: false
---


*注意: 如果不指定`title`, 则会默认从文件名中解析. 在标题为中文时使用, post的文件名避免中文*

# head1

## head2

### head3

#### head4

##### head5

###### head6

列表:

* 测试样式
* 记录markdown语法

列表:

- normal
- **bold**
- *italic*

有序列表

1. 记录1
2. 记录2
3. 记录3

### 代码片段

	def main:
		print("hello word")

行内`main`函数

### 引用

> 主啊
> 赐我毅力, 去改变那些我力所能及之事
> 赐我韧性, 去接受那些我无能为力之事
> 赐我智慧, 去分清这两者的区别

### 水平分隔线

---

### 注释? 没问题

[参考](http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)

html 格式:
<!---
你看不见我
--->

[//]: <> (你也看不见)

### 链接

[链接](http://google.com "this is optional title fields")

自动链接 <http://csyangchen.com>

[引用链接][ref1]


外部图片链接
![](http://ww4.sinaimg.cn/bmiddle/aa397b7fjw1dzplsgpdw5j.jpgfdsafd "alternative")

---

本地图片链接
![](images/marvin.jpg)

---

引用图片
![][paris]

---

[ref1]: http://baidu.com "百度"
[paris]: http://ww4.sinaimg.cn/bmiddle/aa397b7fjw1dzplsgpdw5j.jpg "effel tower"


### GFM (github flavored markdown)

直接生成链接: https://help.github.com/articles/github-flavored-markdown/

code block, with syntax highlighting!

尊
重换行!


```python
def main:
    print("hi")
```

~~deleted contents~~

表格

Left-Aligned  | Center Aligned  | Right Aligned
:------------ |:---------------:| -----:
col 3 is      | some wordy text | $1600
col 2 is      | centered        |   $12
zebra stripes | are neat        |    $1

task list:

- [x] done task
- [ ] to do task


参考:

- <https://guides.github.com/features/mastering-markdown/>
- <http://daringfireball.net/projects/markdown/syntax>

