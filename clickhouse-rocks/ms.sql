drop database if exists test;
create database test;
use test;

create table report (
dt datetime,
uid int,
name varchar(64) not null default '',
cnt int not null default 0,
ct timestamp not null default current_timestamp,
ut timestamp not null default current_timestamp on update current_timestamp,
primary key (uid, dt)
) comment '统计表'
partition by range(to_days(dt))
(partition pYYMMDD values less than maxvalue)
;

create table users (
uid int,
name varchar(64),
primary key (uid)
) comment '用户属性表';

insert into users (uid, name) values
(1, 'a'),
(2, 'b'),
(3, 'c')
;
