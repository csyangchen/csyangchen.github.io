---
title: HTTP GET with Body
---

在和同学做Code Review过程中, 发现虽然协议文档写的是这样的:

    GET /path/to/endpoint
    {"id": 1}

然而实际实现确实这样的:

    GET /path/to/endpoint?q=%7B%22id%22%3A1%7D

或者是这样的:

    PUT /path/to/endpoint
    {"id": 1}

完全不按照约定来啊!
前端同学一再强调, GET请求就不能有Body, 这个完全不符合之前个人的认知啊.
初步调研后, 发现其实这样做其实是有原因的.

首先, 正本清源:
HTTP GET 不能带 Body 这个认识是错误的, HTTP协议并没有明确禁止这一点, 参考Stackoverflow上的[讨论][1].
至于是不是一个好的实践方式有待探讨.

HTTP GET with Body是常见的API设计方式, 如 [Elastic Search][3]. 值得注意的是, 文档中提到, POST方法也是允许的, 就是为了绕过某些客户端限制:

> Both HTTP GET and HTTP POST can be used to execute search with body. Since not all clients support GET with body, POST is allowed as well.

某些HTTP Client Library做了该限制. 常见的命令行工具, 如curl, 编程库的client等, 都是能够GET请求发送Body的, 甚至NodeJS, 都是支持的.

# Javascript http client

XMLRequest 是前端标准的用于请求后端资源的方法, 也是很多前端HTTP库 (如 jQuery, axios) 封装后的具体实现方式.
按照[文档][2]描述:

> send() accepts an optional parameter which lets you specify the request's body; this is primarily used for requests such as PUT. If the request method is GET or HEAD, the body parameter is ignored and the request body is set to null.

简答的一个测试例子:

    f = function(url, body) {
        xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(body))
    }

ES6引入的[Fetch API][4]的行为和XMLRequest一致.

# 结论:

HTTP GET with Body, 和 HTTP POST with Query string 一样, 是允许的. 但也许不是一个好的API设计实践.

绕过办法:

1. 接口设计时避免, 但是query string的设计起来可能就比较麻烦, 尤其是需要一些列表或者嵌套结构的时候, 不方便.
2. urlescape后丢到请求参数中, 缺点是会导致请求头非常长, 需要对请求中间处理环节做好评估, 如[nginx限制][6]等.
   另外需要说明的是, [HTTP协议是没有指定请求参数长度限制的][5]), 也是 client dependent 的行为.
3. 使用POST/PUT方法做查询请求, 属于剑走偏锋的做法.

[1]: https://stackoverflow.com/questions/978061/http-get-with-request-body
[2]: https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/send
[3]: https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-body.html
[4]: https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API
[5]: https://stackoverflow.com/questions/812925/what-is-the-maximum-possible-length-of-a-query-string
[6]: http://nginx.org/en/docs/http/ngx_http_core_module.html#large_client_header_buffers