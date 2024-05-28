# 发现无用依赖

python依赖为什么这么大? 不光PY代码, 还有各种其他so文件, 数据文件等

python的问题在于动态脚本特性, 很难静态分析出来实际依赖关系

编译语言的编译过程只会打包进去实际依赖的代码.
前端编译里面称作"treeshaking", 因为JS文件是实打实要吃流量的, 需要最小化.

检查PIP依赖, 找出项目的外部依赖, 从而找到无用依赖

问题: 有些库的声明的依赖过多, 很多其实并没有被用到

pip check 虽然不过, 但是还是可以正常跑的

在有充分测试覆盖流程的前提下, 找出真正被加载的模块, 从而删掉其余

如果不考虑每个依赖库的完整性, 可以进一步裁剪不需要的文件

对于PY代码, 可以通过找.pyc文件, 或者最后找加载模块字典, 判定是否加载过, 对于非PY文件, 需要在IO层注入判定是否加载过, 从而判定安全删除.


依赖名和import名不一致, 如

- future / past


```
du -d 1 /usr/local/lib/python3.12/site-packages | sort -n
```


py-unused-deps
pipreqs

https://github.com/sclabs/treeshaker


# 自动检查更新依赖

pip list --disable-pip-version-check --not-required
pip list --disable-pip-version-check --outdated | awk 'NR>2 {printf $1"\n"}' > new.txt

