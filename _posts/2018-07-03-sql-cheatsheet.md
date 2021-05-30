---
title: SQL函数相关备忘
---

# 时间相关

Usage | Shell | MySQL | Postgresql | Clickhouse
--- | --- | --- | --- | ---
当前日期(天) | date +%F | curdate() | current_date | today()
当前时间 | date +'%F %T' | now() | now() | now()
当前时间戳 | date +%s | unix_timestamp(now()) | round(extract(epoch from now())) | toUnixTimestamp(now())
当前小时 | date +%H | extract(hour from now()) | extract(hour from now()) | toHour(now())
取整到天 | date +%Y-%m-%d | date_format(now(), "%Y-%m-%d") | date(now()) | toStartOfDay(now())
取整到小时 | | date_format(now(), "%Y-%m-%d %H:00:00") | date_trunc('hour', now()) | toStartOfHour(now())
取整到最近5分钟 | | from_unixtime(floor(unix_timestamp(now())/300)*300) | | toStartOfFiveMinute(now())
昨日 | date +%Y-%m-%d -d'-1 day' | date_add(now(), interval 1 day) | date_add('day', -1, current_date) | today()-1 / yesterday()
时间戳转日期 | date +'%Y-%m-%d %H:%M:%S' -d @1136214245 | from_unixtime(1136214245) | timestamp 'epoch' + 1136214245 * interval '1 seconds' | toDateTime(1136214245)
日期转时间戳 | date +%s -d '2006-01-02 15:04:05' | unix_timestamp('2006-01-02 15:04:05') | extract(epoch from '2006-01-02 15:04:05'::timestamp) | toUnixTimestamp('2006-01-02 15:04:05')
算两个时间间隔 | | | |  

- [MySQL](https://dev.mysql.com/doc/refman/8.0/en/date-and-time-functions.html)
- [Postgresql](https://www.postgresql.org/docs/current/static/functions-datetime.html)
- [Hive](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+UDF#LanguageManualUDF-DateFunctions)
- [Presto](https://prestosql.io/docs/current/functions/datetime.html)
- [Clickhouse](https://clickhouse.tech/docs/en/sql_reference/functions/date_time_functions/)

# JSON相关

- [MySQL](https://dev.mysql.com/doc/refman/8.0/en/json-function-reference.html)
- [Postgresql](https://www.postgresql.org/docs/current/functions-json.html)
- [Hive](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+UDF#LanguageManualUDF-get_json_object)
- [Clickhouse](https://clickhouse.yandex/docs/en/query_language/functions/json_functions/)
