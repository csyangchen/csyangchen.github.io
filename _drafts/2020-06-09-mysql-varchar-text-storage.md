varchar vs text

问题: varchar长度难以预估, 能否统一使用text一劳永逸?

单独存储 ???

索引 ???

row format


- rebundant
- compact
- dynamic
- compressed


maximum row size of 65,535 bytes (64kb) (exclude text/blob)

varchar 限制的是字符长度, 由 charset 最大长度限制.

ERROR 1074 (42000): Column length too big for column 'a' (max = 16383); use BLOB or TEXT instead

- length 字节长度
- char_length 字符长度

存储位置 / InnoDB

off-page

- varchar

index

- text index with prefix


# Full Text Search


# Reference

- https://dev.mysql.com/doc/refman/8.0/en/storage-requirements.html#data-types-storage-reqs-numeric
