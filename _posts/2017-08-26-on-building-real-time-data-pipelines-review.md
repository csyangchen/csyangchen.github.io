---
title: "Building Real-Time Data Pipelines"
---

The book: <http://www1.memsql.com/oreilly.html>

HTAP / Hybrid Transactional/Analytical Processing

OLTP: trade speed with transaction propery

OLAP: Online for ad-hoc query, not Hive / MR Job like query job

- Ingestion latency
- Query latency

Bid gap between OLAP / OLTP, separate data silo, headache of data sync / batch data transfer from OLTP to OLAP / etl process.

Data pattern ~ TSDB

- massive data: IoT / mobile internet / ...
- append write heavy, rarely update
- time window
- need of real time ingestion / consumption & action

Drawback of traditional RDB system:

- ACID compliance, top design goals
    - new realm of business: data loss OK, assume memory reliable enough, ...
- disk based / memory-after mode
- monolithic
- not distributed system, horizontal scale-up difficulty

stream processing problem: hard to keep context / state, e.g. uniq count, attribution, need to rely on external NoSQL (the CEP mode: trade data structure for speed).

pattern: real-time data pipeline + NoSQL for historical lookup / context bookeeping.

custom aggregation / preprocessing layer, requires business logic specific design

semi-structured data schema design

insight: simplicity leads to efficiency

deployment: orchestration frameworks

# Thoughts

- use memory as a cache layer, disk backend
- SQL layer for ease of access / adoption
