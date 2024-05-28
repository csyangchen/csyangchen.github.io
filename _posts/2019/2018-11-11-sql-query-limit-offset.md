---
title: 分页查询SQL优化
---

众所周知, 分页查询 (`order by ... limit n offset n * k`) 是很慢的, 尤其当查询后面几页时.
因为数据库的实现, 是需要对于数据行做 top n*(k+1) 的排序:
单查第一页, 只需要做简单的 top n 排序即可, 内存中一次堆排序, 即可完成;
查最后一页时, 需要对于全表做排序后才能得到结果, 这就可能需要用到文件排序, 自然很慢.

本文记录分页查询的优化思路.

# 排序倒序翻译

翻到最后一页是最差的情形, 此时可以将SQL的排序逻辑改写:

    # FROM
    select ... from ... order by d limit n offset numberOfRows-n
    # TO
    select ... from ... order by d desc limit n offset 0

前提: 需要提前知道总行数信息

一般业务上最容易导致慢的就是此类(查询最后一页), 因为UI上有个最后一页按钮, 然后一手贱...

# 子查询优化

目的: 减少排序中取出的行数据

(From High performance MySQL):

    # FROM
    SELECT film_id, description FROM sakila.film ORDER BY title LIMIT 50, 5;
    # TO
    SELECT film.film_id, film.description
    FROM sakila.film
    INNER JOIN (
    SELECT film_id FROM sakila.film ORDER BY title LIMIT 50, 5
    ) AS lim USING(film_id);

# 使用游标的方式

讨论的例子:

    select * from table where a = ? order by b, c offset N limit M

首先, 查询索引问题, 只有 (a, b, c) 联合索引才有用, 单做 (b, c) 索引并没有用, 因为仍然会先做全表扫描.

如果我们设计上要求分页必须是一页一页往后翻的. 那么, 我们就可以利用上次查询结果, 优化后续的查询:

    select * from table where a = ? and (b > $prev_b or (b = $prev_b and c > $prev_c)) limit M
    # OR
    select * from table where a = ? and (b, c) > ($prev_b, $prev_c) limit M
   
注意 MySQL是支持这样的筛选条件的 `(b, c) < (?, ?)`, 可以走 (b, c) 索引, 并且连`order by b, c`其实也可以省掉了.

## 使用限制条件讨论

首先事务性是没了. 这个看业务场景.

以及不能跳转到任意页面, 因为需要知道前页结果.
只能向后翻页, 如果需要向前翻页, 需要维护更多信息.
故交互页不能输入置顶跳转页的场景, 最多只能提供 "第一页/下一页/上一页/最后页" 的选项.
不过这个业务上的折中个人觉得也能接受, UI上跳到第多少页的按钮真的有人用么?

其次, 要注意, 满足筛选条件行的 (b, c) 组合不能出现重复.
如果出现重复, 虽说也能处理, 但是也很麻烦: 需要算出上一页最后(b, c)重复的行数, 并在下页查询中额外跳过.
所以如果可以, 尽量通过唯一索引来做游标.

这种优化局限于瀑布流式的数据查询需求.

# 外部缓存方式

order by limit offset计算外部化.

将查询全表的结果 (一般是开销较大的聚合查询结果) 缓存下来.
后续的分页, 或者指定列的排序, 基于缓存数据来做, 就非常快.
查询全表缓存存储既可以是数据库中的临时表, 也可以是外部存储.
这种对于数据库查询压力最小.
缺点出了牺牲数据一致性外, 外部系统也需要做很重的数据处理逻辑.

参考Redash的实现.

# Reference

- <https://www.slideshare.net/MarkusWinand/p2d2-pagination-done-the-postgresql-way>
