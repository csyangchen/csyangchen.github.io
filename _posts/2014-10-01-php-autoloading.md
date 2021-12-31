---
title: PHP代码自动加载
tags: php
---

PHP最初作为一种动态生成网页的语言出现, 注重面向过程的写法, 缺少很多面向对象语言的特性.
在5.0版本以后才逐步引入了有限的面向对象编程的支持.
这种后天的语法添加, 导致PHP本身先天不良, 没能提供一个类似于java的良好的类代码组织规则.
这就需要我们在用面向对象方式做PHP开发时, 要注意到类代码组织和加载的问题, 以及和三方库的良好互通性.

这篇文章, 我们就来说说, 这些年来, 我们是如何加载php代码的.

### 从一个短平快的脚本说起

一开始, 在实现功能需求时, 为了图方便, 把多个类, 以及直接逻辑操作的代码, 混放在在一个文件里. 简单有效, get things done!
当随着统计脚本需求的不断变化, 代码复杂性的不断增加, 从代码复用性的考虑, 把所有代码组织在一个源文件里面, 就显得不太合适了.
于是我们需要把可复用的, 不产生副作用的"通用代码"(如类定义, 函数定义等), 和业务相关的"执行逻辑脚本", 分离开来.
一个可行的方案是: 通过一个注册文件, 将"通用代码"逐一`require`进来, 执行脚本引入这个注册文件, 从而见到所有的代码声明.

于是在用类组织代码的时候, 为了方便查找, 应当遵循java的约定, **一个类一个文件, 类名称和文件名对应**, 虽然有时觉得一个类一个文件非常繁冗, 但确实这是一个比较好的习惯.

例子:

	> ls .
	Db.php
	Util.php
	header.php
	calc_day_login.php
	> cat Db.php
	class Db
	{
		...
	}
	> cat Util.php
	class Util
	{
		...
	}
	> cat headers.php
	require('Db.php');
	require('Util.php');
	> cat calc_day_login.php
	require('headers.php');
	...
	$sql = "select * from xxoo";
	Util::println($sql);
	$db = new Db();
	$db->query($sql);

### 自动加载帮到您

但是, 当项目越来越大的时候, 上述的处理手法, 会遇到一些实际问题:

- 太麻烦了! 当文件目录结构变化, 或者文件名称变化的时候, 都需要记得修改这个全局的注册文件
- 不好扩展. 当代码变得越来越复杂, 需要多方协同参与的时候, 需要慎重处理潜在的类命名的冲突
- 性能. 因为在每趟执行的时候都需要将包含的所有文件编译一遍, 而可能只有极少数代码在这次执行过程中是用到的

于是求助手册, 发现似乎`__autoload`这个魔术方法能够帮我们解决这个问题: **让代码在真正需要的时候才加载进来**.

于是, 我们可以把`header.php`, 一劳永逸的替换成:

	function __autoload($className) {
	    $filename = $className . ".php";
	    if (is_readable($filename)) {
	        require $filename;
	    }
	}

这样, 我们省去了每添加一个类文件, 就需要在注册文件`header.php`里面同步修改的麻烦. 同时也省去了每次执行时, 编译用不到的代码文件的开销.

可是, 由于`__autoload`只能定义一个具体的类加载器, 当项目越来越大, 并且包括了多方的代码时, 仅仅通过一个`__autoload`的这个入口的方式加载类变得困难重重. 于是在5.1.2版本引入了`spl_autoload_register`函数, 支持多个类加载器, 并可以指定加载的优先级.
	
	function autoloadVendor1($classname)
	{
	    $filename = sprintf("vendor/vendor1/%s.php", $classname);
	    if (is_readable($filename)) {
	        require($filename);
	    }
	}
	
	function autoloadVendor2($classname)
	{
	    $filename = sprintf("vendor/vendor2/%s.php", $classname);
	    if (is_readable($filename)) {
	        require($filename);
	    }
	}
	
	spl_autoload_register('autoloadVendor1');
	# 先调用autoloadVendor2加载器
	# spl_autoload_register('autoloadVendor2', true, true);

到这里, 类自动加载的问题似乎已经解决了, 但是仍然存在命名冲突的问题.

### FIG标准化的尝试

在5.3入前, 为了解决没有命名空间的问题, 大家在类命名规则上做手脚, 每个项目的代码的组织形式, 命名规则, 甚至扩展名, 各不一样.
在(丑陋的)命名空间语法于5.3引入后, 为了解决PHP代码的互通性的问题, 一帮人成立了FIG组织([Framework Interoperatability Group](http://www.php-fig.org/)).

标准是重要的. java由于只有一家公司开发, 类声明的文件路径与其命名空间之间形成了约定俗成的映射关系.
而PHP, 由于没有一开始引入命名空间, 导致大家的做法百花齐放, 于是所以在制定[PSR-0](http://www.php-fig.org/psr/psr-0/)标准以解决加载器胡同问题时, 只能兼容成规.

PSR-0的类名到查找文件的例子:

	Zend_Mail_Message => /path/to/project/lib/vendor/Zend/Mail/Message.php
	\Zend\Mail\Message => /path/to/project/lib/vendor/Zend/Mail/Message.php

于是, 如果我们自己的代码按照PSR-0的规则来组织, 只要注册的加载器是支持PSR-0的, 就不用担心`Class undefined`的问题了.

PSR-0标准出来之后不久, 有些人觉得用得不爽. 于是又提了一个[PSR-4](http://www.php-fig.org/psr/psr-4/)标准, 和PSR-0的主要区别在于更加地灵活简洁的代码组织结构, 并旧代码一刀两断, 果断移除了对于5.3之前, 如`Zend_Mail_Message`这种PEAR命名规则的支持.

### 利用composer自动构建

当一个项目越来越大之后, 全部代码自己从零开始是不现实的, 引入通用的代码组件才是必然之路.
然而每次维护通用代码组件的依赖关系好麻烦, 经常写java的同学呢, 就会开始怀念起类似maven之类的工具. 于是就有人弄了[composer](https://getcomposer.org/)工具, 也就是PHP版本的maven, 用来自动维护项目对于第三方代码的依赖:

	> cat composer.json
	{
	    "require": {
	        "monolog/monolog": "1.2.*"
	    }
	}
	> composer install
	// 所依赖的代码被自动拖到了项目的vendor目录下
	> cat test.php
	require 'vendor/autoload.php';
	$log = new Monolog\Logger('name');
	// 可以用了~

注意的是, composer既支持PSR-0, 也支持PSR-4的代码组织形式.

当然, 和maven一样, composer也支持指定私有仓库, 一个项目写的代码, 可以很方便地被另外一个项目引用进来.

### 总结

好了. 到这里, 一路走来, 我们了解了这些PHP类加载的规则和工具, 以后每次写PHP项目时, 尽可能的使用通用的做法, 不用再自己憋一套机制出来了.