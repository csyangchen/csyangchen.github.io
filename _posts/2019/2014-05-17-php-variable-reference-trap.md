---
title: PHP变量引用坑一则
---

最近工作中遇到了类似的奇怪问题:

	<?php
	$arr = array(1, 2, 3);
	foreach ($arr as &$item) { ... }
	foreach ($arr as $item) { ... }
	print_r($arr);
	// outputs:
	Array
	(
	    [0] => 1
	    [1] => 2
	    [2] => 2
	)

### 原因分析

**PHP的变量作用域是函数级别的**.
即在函数范围内, 一个变量一旦定义了, 就是可见了. 这不同于C++/java等严格的编译型语言, 变量作用域仅仅在代码块级别(block-level)可见.

所以类似如下的代码行为也就可以理解了:

	foreach (array(1, 2, 3) as $x) {
	    ;
	}
	echo $x;
	// output 3

当然, 类似的情况同样出现在python, javascript等脚本语言身上.
绝大部分时候, 大家没觉得变量生存区域的延伸到作用块外是个很大问题, 因为默认变量(基本上)是引用语义.
然而PHP变量, 由于区分值语义/引用语义, 那么就问题来了.

对于开头所述的代码, 当第一个foreach结束后, $item变量指向了数组最后一个成员, 在第二次foreach循环中, 实际执行了:

	$arr[2] = $arr[0];
	$arr[2] = $arr[1];
	$arr[2] = $arr[2];

从而导致上述意料之外的结果.

### 解决办法

- 对于PHP代码开发而言, 按照PHP手册建议, 在引用变量的期望作用区域结束后, 养成随手unset掉的习惯, 以解除引用关系

		foreach ($arr => &$x) {
		     ...
		} unset $x;

- 个人建议: 避免使用引用变量. PHP数组的CopyOnWrite很棒, 让我们可以把数据当作不变量随意的传递, 而不用担心side effect.


[PHP就此展开过跨度近10年的讨论!](https://bugs.php.net/bug.php?id=29992)

---

### 延伸1

另外, 在PHP(Python, javascript, ...)中, 常常会这样因为变量作用域问题所导致的BUG:

	foreach (array(1, 2, 3) as $k) {
	    foreach (array(1, 2, 3) as $k) {
	        echo $k;
	    }
	    // $k = 3
	    ...
	    // do something with the wrong $k;
	}

个人不推荐这样的写法, 更倾向于把内外两层分拆成独立的业务逻辑去操作.
当看到一个函数里面有多的串行, 嵌套, 以及条件判断分割出来的并行的遍历时, 就应当及时嗅出代码的坏味道来了.


### 延伸2

看到PHP的这种代码:

    foreach ($cfg as $k => $v) {
        $$k = $v;
    }

或

    extract($cfg);

时, 整个人都不好了. 虽然显得很聪明, 但是非常难读, 而且有污染变量的潜在危险, 慎用!
