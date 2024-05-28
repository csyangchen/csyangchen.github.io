---
title: POP流量介绍
---

# pop-up & pop-under

网盟常见的流量来自于pop(弹窗)广告位. 顾名思意, 在用户点击的时候触发弹出另外一个窗口, 用于展示广告. 和诱导下载链接, auto-redirect, 等等, 都属于互联网上的旁路流量利用.

在实现方式上, 细分为pop-up和pop-under. 一个是在当前页面前弹出 (pop-up), 另一个则是在后台打开新窗口 (pop-under).
从体验上来说, pop-up体验很差, 打扰了用户的当前行为;
相对而言, pop-under会好一些, 只有当用户关闭了浏览的页面后, 才会发现还有个弹窗广告, 更妙的是, 用户甚至不太清楚广告页到底是从之前具体哪个页面弹出的.

# pop流量利用要点

由于pop广告位本身并非用户意图, 因此要引起用户注意, 产生后续行为, 最重要的一点就是: 素材要足够诱人! 要在用户找到关闭按钮前, 对于弹窗的内容产生不可抗拒的注意力. 具体示例就不列举了, 相信各位冲浪老司机的经验.

# pop实现机制

pop-under的一个最简例子, 监听点击事件, 始终将目标链接在新窗口打开, 并将本页面重定向到pop_url. 这种方式在同一个窗口, 不同的标签来中打开实现.

        <head>
        <script>
        var pop_url = "https://www.baidu.com"
        function pop(e) {
                if (e.target.tagName=="A") { // 判断下是否点击的是A标签元素
                        e.target.target = "_blank";
                        document.location.assign(pop_url);
                }
        }
        document.addEventListener("click", pop, false)
        </script>
        </head>
        <body>
        <a href="http://www.bing.com">Click</a>
        </body>

同理, pop-up的最简单例子

        <head>
        <script>
        var pop_url = "https://www.baidu.com"
        function pop(e) {
            if (e.target.tagName=="A") {
                window.open(pop_url, "pop-up title goes here", "dependent=yes");
            }
        }
        document.addEventListener("click", pop, false)
        </script>
        </head>
        <body>
        <a href="http://www.bing.com">Click</a>
        </body>

基于windows.open的pop-under的另外一种实现方式, 将焦点转回到跳转页面. 其他类似hacking机制不再列举, Just Google it

        <head>
        <script>
        var pop_url = "https://www.baidu.com"
        function pop(e) {
            if (e.target.tagName=="A") {
                window.open(pop_url, "pop-up title goes here", "dependent=yes");
                window.open().close(); // NOTE: magic happens here
            }
        }
        document.addEventListener("click", pop, false)
        </script>
        </head>
        <body>
        <a href="http://www.bing.com">Click</a>
        </body>

在实际网站使用中, 为了体验考虑, 会限制只针对某些元素触发跳转. 以及种植Cookie的方式来限制弹出频次. 参考各著名大人网站.

顺便提一下redirect流量实现机制, 利用了HTML中如下功能, 即在当前页面停留一段时间后自动跳转到目标页面:

        <meta http-equiv="refresh" content="seconds-for-current-page-to-wait; URL=other-web-address">

# 防范措施

作为渠道, 会想办法利用此类机制, 制造更多的流量, 已期产生利用. 但是作为用户, 更多的是种困扰. 幸运的是, 浏览器设定, 支持屏蔽掉弹窗/redirect机制.

Google爸爸也会侦测此类的网站, 标记为不安全, 并提示用户. Chrome对于通过调用windows.open方法打开窗口也有一定的安全和屏蔽机制.

也可以通过一些广告屏蔽浏览器插件, Block掉相关恶意内容.

当然魔高一尺, 道高一丈, 总会有人想办法, 利用机制绕过, 或者浏览器之类的漏洞, 甚至设备种植病毒, 实现对于防范机制的绕过.

# 参考

- <https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener>
- <https://developer.mozilla.org/en-US/docs/Web/API/Window/open>

最后吐槽一下, HMLT/Javascript设计这么多奇奇怪怪的机制, 实在不知道当时设计的时候咋想的.
