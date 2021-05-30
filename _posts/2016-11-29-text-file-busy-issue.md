---
title: Text File Busy 问题讨论
---

由头: 在更新Linux服务器上正在运行的程序时, 直接通过`scp`更新会报`Text file busy`的错误, 而利用`ansible -m copy`, 则能够正常覆盖目标文件. 这是什么原因呢？

其实不光`scp`, 直接`cp`一个正在打开的文件也会同样报错. 改用`cp -f`则能够正常覆盖, 用`mv`也能达到同样目的. 这里面机制有什么不同呢？

跟踪一下`cp -f`的系统调用:

	# strace cp -f src dst
	...
	open("dst", O_WRONLY|O_TRUNC)             = -1 ETXTBSY (Text file busy)
	unlink("dst")                             = 0
	open("dst", O_WRONLY|O_CREAT|O_EXCL, 0775) = 4
	...
	
可以看到, 在不能正常打开目标文件后, 首先调用`unlink`“删除”之, 然后创建一个新的文件.
这里“删除”之所以打引号, 是因为该删除操作对于目前使用该文件的进程是透明的, 仍然可以正常读写, 参考`unlink(2)`的文档:

	   If the name was the last link to a file but any processes still have the file open, the file will remain in existence until  the  last  file
	   descriptor referring to it is closed.

另外提一点, `rm`命令也是通过调用`unlink`来“删除”文件.

看下`mv`命令的系统调用

	# strace mv src dst
	...
	access("dst", W_OK)
	rename("src", "dst")

可以发现, `mv`先检查下是否有写目标文件权限, 然后执行的是`rename`系统调用（当然这个也不严格正确, 和文件是否处于同一挂在点下有关, 不同挂载点下文件`mv`, 先执行拷贝操作, 然后再调用`rename`）,
不涉及到对现有目标文件的写操作, 因此也就不会遇到`Text file busy`的问题.

通过`ls -i`, 可以看到, `cp`前后, 目标文件文件inode值不变; `cp -f`后, inode值发生了变化; `mv src dst`后, dst的inode值和原来src的相同.

回到我们的由头:
`scp`直接打开目标文件进行写入, 因此会遇到问题;
`ansible copy`是先将文件拷贝到目标机器的一个临时目录, 然后`mv`到目标文件, 故可以正常覆盖.

总结一下:

对于可执行文件来说, 在执行伊始, 整个文件已经加载到内存中了. 修改执行文件内容对于在运行进程没有影响.
可以通过`unlink`或者`rename`系统调用安全覆盖掉原有文件.

另一方面, 如果`cp -f`/`mv`其他程序正在写入的文件, 那么就会发生数据丢失的问题. 这种场景下, 就需要通过额外的机制, 如文件权限等, 来保证写入的安全.
