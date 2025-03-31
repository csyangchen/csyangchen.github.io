---
title: MySQL查询问题集锦
published: false
---


select id, createdAt from advertisement where id in (
select id from advertisement order by id desc limit 10
)

This version of MySQL doesn't yet support 'LIMIT & IN/ALL/ANY/SOME subquery'


explain
select id from advertisement where id in (
select max(id)-10000 from advertisement
)


explain
select id from advertisement,
(select max(id)-10000 as aid from advertisement) t
where id=t.aid