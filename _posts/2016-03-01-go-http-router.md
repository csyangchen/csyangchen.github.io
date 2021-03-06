---
title: Golang HTTP路由调研
tags: golang
---

路由是每个Web框架非常重要的一环, 这里我们调研一下几个Go路由的实现.

### http.ServeMux

`http.ServeMux` 是标准库自带的URL路由.
其实现比较简单, 每个路径注册到一个字典里面, 查找的时候, 遍历字典, 并匹配最长路径.

    package http

    // 回调函数接口
    type HandlerFunc func(ResponseWriter, *Request)


    // 路由结构
    type ServeMux struct {
    	mu    sync.RWMutex
    	m     map[string]muxEntry // 路由查找字典
    	hosts bool // whether any patterns contain hostnames
    }

    // 注册路由
    func (mux *ServeMux) Handle(pattern string, handler Handler)

    // 路由查找逻辑
    func (mux *ServeMux) match(path string) (h Handler, pattern string) {
    	var n = 0
    	for k, v := range mux.m {
    		if !pathMatch(k, path) {
    			continue
    		}
    		if h == nil || len(k) > n {
    			n = len(k)
    			h = v.h
    			pattern = v.pattern
    		}
    	}
    	return
    }

    func pathMatch(pattern, path string) bool {
    	if len(pattern) == 0 {
    		// should not happen
    		return false
    	}
    	n := len(pattern)
    	if pattern[n-1] != '/' {
    		return pattern == path
    	}
    	return len(path) >= n && path[0:n] == pattern
    }

`http.ServeMux`的局限性:

- 不能够根据请求方法路由
- 处理每次请求, 会遍历一遍字典, 性能不好
- 不支持动态路由, URL里面的路径参数需要自己解析Path去做
- 根据最长匹配来分发, 存在一个请求有潜在多个接收者的情况, 可能造成困惑, 例:

        userMux := http.NewServeMux()
        userMux.HandleFunc("/", userDefaultHandler) // handle /user/*
        userMux.HandleFunc("/list", userListHandler) // handle /user/list

        mux := http.NewServeMux()
        mux.HandleFunc("/user", evilUserHandler)
        mux.Handle("/user/", userMux)
        mux.HandleFunc("/user/list", evilUserListHander) // override previous handler

        GET /user => evilUserHandler
        GET /user/ => userDefaultHandler
        GET /user/yangchen => userDefaultHandler
        GET /user/list => evilUserListHander

### httprouter

目前项目使用的是`gin`, 其路由采用了`httprouter`.
相对于 `http.ServeMux`, `httprouter`支持:

- 根据方法注册路由
- 支持动态路由

我们来看下其路由解析实现:

    package httprouter

    // 回调函数接口, 提供了Params参数
    type Handle func(http.ResponseWriter, *http.Request, Params)

    // 注册路由, 多了method参数
    func (r *Router) Handle(method, path string, handle Handle)

    // 路由结构
    type Router struct {
    	trees map[string]*node // 路由查找树
        ...
    }

    // 节点结构
    type node struct {
        path      string
        wildChild bool
        nType     nodeType
        maxParams uint8
        indices   string
        children  []*node
        handle    Handle
        priority  uint32
    }

    // 路由查找逻辑
    func (n *node) getValue(path string) (handle Handle, p Params, tsr bool) {
    walk: // outer loop for walking the tree
        for {
            if len(path) > len(n.path) {
                if path[:len(n.path)] == n.path {
                    path = path[len(n.path):]
                    ...
                    c := path[0]
                    for i := 0; i < len(n.indices); i++ {
                        if c == n.indices[i] {
                            n = n.children[i]
                            continue walk
                        }
                    }
                    ...
            } else if path == n.path {
                // We should have reached the node containing the handle.
                // Check if this node has a handle registered.
                if handle = n.handle; handle != nil {
                    return
                }
                ...
            }
        }
        ...
    }

从路由实现上来看, 用了 radix tree 的结构, 查找的时候更加高效;
在遇到匹配的时候立即返回, 不像`http.ServeMux`需要遍历决议.

#### 问题

由于其精确路由, 因此没法把部分路由功能分发到另外一个路由器中. 也就是说, 一旦上了车, 就下不来了.

例如 `net/http/pprof.Index` 自己实现了子路经的派发功能, 就很难嵌入到 `httprouter` 中去.

同一路径下不支持固定路径和参数路径共存, 例

    r.GET("/list", listHandler)
    r.GET("/:method", dispatchHandler)
    // runtime panic

参见[这里](https://github.com/julienschmidt/httprouter/issues/73).

虽然这是特性而不是BUG, 但是使用过程中确有不爽.

### gin

gin 的路由器是基于 httprouter 的. 提几个比较有用的功能:

- 链式, 插件化的中间层(MiddleWare)模块支持, 很方便增加日志/监控/限流等通用功能
- 支持路由组(RouterGroup)的写法, 从而注册HTTP服务模块不需要关心服务的绝对路径, 方便组合
- 数据绑定(Binding)等帮助方法, 当然这些和我们这里主要讨论的路由功能就扯得比较远了

看个例子

    r := gin.New()
    g := r.Group("/user")
    // 每个路由组可以共用中间层
    g.Use(ThrottleHanler)
    // 注册api相关方法
    g.GET("/list", ...)
    // ...


### beego

`beego`是国人开发的Web开发框架, 在`go-http-routing-benchmark`中, 其路由性能似乎表现不佳, 我们来深究下原因.

看一下其路由实现, 也是使用了查找树, 但是对子节点查找时, 需要遍历, 而`httprouter`的每个节点, 保存了对于其子节点的路由信息`node.indices`, 查找上自然更快.
此外, `beego`路由查找方法使用了递归的方式(`Tree.match`), 而`httprouter`在一个执行循环(`node.getValue`)里就可以搞定, 自然效率更高.

    // 路由结构
    type ControllerRegister struct {
    	routers      map[string]*Tree // 路由查找树
    	...
    }

    // 节点结构
    // Tree has three elements: FixRouter/wildcard/leaves
    // fixRouter sotres Fixed Router
    // wildcard stores params
    // leaves store the endpoint information
    type Tree struct {
    	//prefix set for static router
    	prefix string
    	//search fix route first
    	fixrouters []*Tree
    	//if set, failure to match fixrouters search then search wildcard
    	wildcard *Tree
    	//if set, failure to match wildcard search
    	leaves []*leafInfo
    }

    // 路由查找逻辑
    func (t *Tree) match(pattern string, wildcardValues []string, ctx *context.Context) (runObject interface{}) {
        ...
        for _, subTree := range t.fixrouters {
            if subTree.prefix == seg {
                runObject = subTree.match(pattern, wildcardValues, ctx)
                if runObject != nil {
                    break
                }
            }
        }
        ...
    }

当然, 拿`httprouter`一个纯路由库, 和`beego`这样一个功能丰富的MVC开发框架, 是不公平的.

`beego`路由模块和Controller联系紧密, 提供了更加丰富的功能, 如大小写识别, 路由过滤器等.
列两点看上去挺有用的特性:

 - 路由规则支持正则, 如

         /api/:id([0-9]+

 - 路径后缀参数也会提供, 而不是路由失效, 例子:

         # 路由规则
         /user/:name => handler

         # 请求路径
         /user/alice/2016/01/01

         httprouter => 404
         beego => handler // ctx.Input.Params = {0: 2016, 1: 01, 2: 02}

### 总结

对于路由选择, 够用就好, `http.ServeMux` 从功能以及性能上都不够令人满意, 建议用 `httprouter` 替代.
如果做后端API服务, gin挺趁手, 功能基本够用了.
`beego` 的路由, 是为了其MVC框架服务的, 不方便单独拿出来用.

### 参考连接

- [gin](https://github.com/gin-gonic/gin)
- [httprouter](https://github.com/julienschmidt/httprouter)
- [go-http-routing-benchmark](https://github.com/julienschmidt/go-http-routing-benchmark)
- [radix_tree](https://en.wikipedia.org/wiki/Radix_tree)
