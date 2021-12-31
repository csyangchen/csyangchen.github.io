---
title: 服务器安装
---

在工作和学习中, 常需要在windows环境下通过虚拟机软件安装Linux系统, 作为测试环境.
另外, 有时后个人需要维护一台VPS. 
在服务器的安装和维护过程中, 常遇到各种问题. 在这里, 本着能偷懒就偷懒的原则, 这里记录下来, 作为备忘. 

本笔记基于centos系列.

## VirtualBox下的安装

### 网络

默认分配一个NAT网络, 通过DHCP自动获取IP.

除了NAT网络, 另外加一个Host only adapter, 以获取一个固定IP.

配置:
    > vi /etc/sysconfig/network-scripts/ifcfg-eth1 # 
    # 作如下修改
    ONBOOT=yes
    BOOTPROTO=static
    IPADDR=192.168.56.123
    # 重启网络已生效
    > service network restart

windows下测试是否联通:
    
    > ping 192.168.56.123

**注意:** 注意由于默认情况下

- `192.168.56.1/24` 为host only adapter网段
- `192.168.56.100` 为host only DHCP server

所以设置IP的时候要在`192.168.56.1/24`网段, 同时避免`192.168.56.100`. 也可以在virtualbox的file->preferences->network->host-only networks中修改.

### guest addons

为了更方便的使用虚拟机, 我们通常需要安装VirtualBox的guest addon. 这样就可以把宿主机上的目录很方便的加载在虚拟机上, 进行读写.

手动加载`C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso`, 
    
    # 安装依赖
    > yum install kernel-devel -y
    # 加载iso文件  
    > mount -r -t auto /dev/sr0 /mnt
    > /mnt/VBoxLinuxAdditions.run
    
加载目录
    
    > mount -t vboxsf <宿主机共享目录名> <目标路径>

## 安全措施

网络环境凶险, 分分钟都有非常暴力的扫端口事件. 个人主要观察到的就是ssh(22)端口暴力尝试, http(80)端口各种漏洞尝试.

基本原则是:
- 暴露的端口尽量少
- 高端一点的手段就是隐藏端口

### 防火墙配置

防火墙视服务器提供方默认设置而定, 要慎重`iptables -F`, 因为有可能会导致ssh都失效, 要请人去机房手动重启.

    > vim /etc/sysconfig/iptables
    > # 添加规则
    > iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
    > service iptables reload
    > # 查看规则
    > iptables -L

### SSH公钥登陆

SSH服务防御措施

    vim /etc/ssh/sshd_config
    # 避免使用密码登录, 避免暴力破解
    # PasswordAuthentication no
    # 改变默认端口
    Port 22
    
    # 禁止root登陆
    # PermitRootLogin no

个人觉得SSH禁止密码登录就OK了.

公钥添加到`.ssh/authorized_keys`时, 要特别注意权限问题:
    
    > chmod 700 .ssh/
    > chmod 600 .ssh/authorized_keys

生成公钥: `ssh-keygen`命令, 注意可以通过设置`passphrase`来密码保护私钥. 如果日后觉得每次请求密钥都要输密码麻烦, 可以用`ssh-keygen -p`来去除.

OK, 之后采用证书方式登陆吧, 也省去了每次登陆敲密码的麻烦.
