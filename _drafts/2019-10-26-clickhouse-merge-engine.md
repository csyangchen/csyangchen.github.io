```

2019.10.25 17:40:24.805566 [ 93 ] {a29b94f6-48ab-43b8-8b29-aac7a3956ded} <Trace> mt.spiderlog: Renaming temporary part tmp_insert_20191025_98_98_0 to 20191025_98_98_0.

# 事务提交触发合并
2019.10.25 17:50:31.326966 [ 93 ] {1f564ef1-cc79-47b5-b9e0-ce1a287bdf90} <Trace> mt.spiderlog: Renaming temporary part tmp_insert_20191025_103_103_0 to 20191025_103_103_0.

2019.10.25 17:50:31.331742 [ 2 ] {} <Debug> mt.spiderlog (MergerMutator): Selected 6 parts from 20191025_98_98_0 to 20191025_103_103_0
2019.10.25 17:50:31.331791 [ 2 ] {} <Debug> mt.spiderlog (MergerMutator): Merging 6 parts: from 20191025_98_98_0 to 20191025_103_103_0 into tmp_merge_20191025_98_103_1
2019.10.25 17:50:31.332612 [ 2 ] {} <Debug> mt.spiderlog (MergerMutator): Selected MergeAlgorithm: Horizontal

2019.10.25 17:50:31.332645 [ 2 ] {} <Trace> MergeTreeSequentialBlockInputStream: Reading 6 marks from part 20191025_98_98_0, total 2899 rows starting from the beginning of the part, columns: uid, spider_id, device
, platform, channel, media, catch_account_id, section_id, area_cc, response, status, ext, priority, ts_crawl, response_headers, response_content_type, spider_name, request_url, request_headers, request_method, req
uest_params, proxy_info, data_source, app_id, dt
2019.10.25 17:50:31.333161 [ 2 ] {} <Trace> MergeTreeSequentialBlockInputStream: Reading 17 marks from part 20191025_99_99_0, total 10000 rows starting from the beginning of the part, columns: uid, spider_id, devi
ce, platform, channel, media, catch_account_id, section_id, area_cc, response, status, ext, priority, ts_crawl, response_headers, response_content_type, spider_name, request_url, request_headers, request_method, r
equest_params, proxy_info, data_source, app_id, dt
2019.10.25 17:50:31.333698 [ 2 ] {} <Trace> MergeTreeSequentialBlockInputStream: Reading 15 marks from part 20191025_100_100_0, total 8579 rows starting from the beginning of the part, columns: uid, spider_id, dev
ice, platform, channel, media, catch_account_id, section_id, area_cc, response, status, ext, priority, ts_crawl, response_headers, response_content_type, spider_name, request_url, request_headers, request_method,
request_params, proxy_info, data_source, app_id, dt
2019.10.25 17:50:31.334177 [ 2 ] {} <Trace> MergeTreeSequentialBlockInputStream: Reading 17 marks from part 20191025_101_101_0, total 10000 rows starting from the beginning of the part, columns: uid, spider_id, de
vice, platform, channel, media, catch_account_id, section_id, area_cc, response, status, ext, priority, ts_crawl, response_headers, response_content_type, spider_name, request_url, request_headers, request_method,
 request_params, proxy_info, data_source, app_id, dt
2019.10.25 17:50:31.334766 [ 2 ] {} <Trace> MergeTreeSequentialBlockInputStream: Reading 17 marks from part 20191025_102_102_0, total 10000 rows starting from the beginning of the part, columns: uid, spider_id, device, platform, channel, media, catch_account_id, section_id, area_cc, response, status, ext, priority, ts_crawl, response_headers, response_content_type, spider_name, request_url, request_headers, request_method, request_params, proxy_info, data_source, app_id, dt
2019.10.25 17:50:31.335241 [ 2 ] {} <Trace> MergeTreeSequentialBlockInputStream: Reading 16 marks from part 20191025_103_103_0, total 9650 rows starting from the beginning of the part, columns: uid, spider_id, device, platform, channel, media, catch_account_id, section_id, area_cc, response, status, ext, priority, ts_crawl, response_headers, response_content_type, spider_name, request_url, request_headers, request_method, request_params, proxy_info, data_source, app_id, dt

# TODO 内存使用
2019.10.25 17:50:31.336666 [ 93 ] {1f564ef1-cc79-47b5-b9e0-ce1a287bdf90} <Debug> MemoryTracker: Peak memory usage (total): 353.81 MiB.

2019.10.25 17:50:33.710264 [ 2 ] {} <Debug> mt.spiderlog (MergerMutator): Merge sorted 51128 rows, containing 25 columns (25 merged, 0 gathered) in 2.38 sec., 21496.30 rows/sec., 351.10 MB/sec.
2019.10.25 17:50:33.715440 [ 2 ] {} <Trace> mt.spiderlog: Renaming temporary part tmp_merge_20191025_98_103_1 to 20191025_98_103_1.
2019.10.25 17:50:33.715588 [ 2 ] {} <Trace> mt.spiderlog (MergerMutator): Merged 6 parts: from 20191025_98_98_0 to 20191025_103_103_0

...

2019.10.25 18:00:30.568468 [ 16 ] {} <Trace> mt.spiderlog: Found 6 old parts to remove.
2019.10.25 18:00:30.568488 [ 16 ] {} <Debug> mt.spiderlog: Removing part from filesystem 20191025_98_98_0
2019.10.25 18:00:30.571263 [ 16 ] {} <Debug> mt.spiderlog: Removing part from filesystem 20191025_99_99_0
2019.10.25 18:00:30.576487 [ 16 ] {} <Debug> mt.spiderlog: Removing part from filesystem 20191025_100_100_0
2019.10.25 18:00:30.580751 [ 16 ] {} <Debug> mt.spiderlog: Removing part from filesystem 20191025_101_101_0
2019.10.25 18:00:30.585626 [ 16 ] {} <Debug> mt.spiderlog: Removing part from filesystem 20191025_102_102_0
2019.10.25 18:00:30.590170 [ 16 ] {} <Debug> mt.spiderlog: Removing part from filesystem 20191025_103_103_0
2019.10.25 18:00:30.598377 [ 16 ] {} <Debug> mt.spiderlog (MergerMutator): Selected 9 parts from 20191025_77_83_1 to 20191025_107_107_0
2019.10.25 18:00:30.598405 [ 16 ] {} <Debug> mt.spiderlog (MergerMutator): Merging 9 parts: from 20191025_77_83_1 to 20191025_107_107_0 into tmp_merge_20191025_77_107_2
2019.10.25 18:00:30.599558 [ 16 ] {} <Debug> mt.spiderlog (MergerMutator): Selected MergeAlgorithm: Vertical
2019.10.25 18:00:39.686586 [ 16 ] {} <Debug> mt.spiderlog (MergerMutator): Merge sorted 252655 rows, containing 25 columns (1 merged, 24 gathered) in 9.09 sec., 27800.42 rows/sec., 473.78 MB/sec.
2019.10.25 18:00:39.686890 [ 16 ] {} <Trace> mt.spiderlog: Renaming temporary part tmp_merge_20191025_77_107_2 to 20191025_77_107_2.
2019.10.25 18:00:39.687055 [ 16 ] {} <Trace> mt.spiderlog (MergerMutator): Merged 9 parts: from 20191025_77_83_1 to 20191025_107_107_0


```


# Merge Engine


- Primary Key: 写入index的字段
- Sorting Key: 数据排序字段
- partition
- parts
- granules

# 文件结构

定时提交事务, 每次事务中提交的数量不可控.
增加每次提交行数限制.

# write transaction

必须要开事务写入.

COMMIT

tmp_insert_20191022_10_10_0 -> 20191022_10_10_0

tmp_insert_* 数量 = 本次事务涉及分区数量.

partition_name = "{partition_id}_{min_block_number}_{max_block_number}_{level}"

commit 时候触发文件改写, 文件可见.

/var/lib/clickhouse/data/{database}/{table}/tmp_insert_{partition_name}
/var/lib/clickhouse/data/{database}/{table}/{partition_name} <-> system.parts.name

# .../{partition_name}/

- checksums.txt
- columns.txt
- count.txt
- {column}.bin
- {column}.mrk2
- minmax_{column}.idx
- primary.idx
- partition.dat

# background merge

如果写入时候已经按照order by排序, 则merge不占用内存.

TODO

- Selected MergeAlgorithm: Horizontal
- Selected MergeAlgorithm: Vertical
- MergerMutator


# Data Skipping Indexes

GRANULARITY

skip block of data

# Update Data

## *MergeTree

## mutations


# Reference

- [Merge Tree](https://clickhouse.yandex/docs/en/operations/table_engines/mergetree/)
- [system.parts](https://clickhouse.yandex/docs/en/operations/system_tables/#system_tables-parts)

- https://www.percona.com/blog/2018/01/09/updating-deleting-rows-clickhouse-part-1/
- https://www.percona.com/blog/2018/01/16/updating-deleting-rows-from-clickhouse-part-2/
