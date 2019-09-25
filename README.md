# ioc.lua
一个lua实现的依赖注入库

# 特色
实现了两个主要功能:
* 依赖注入
* 延迟求值

# 用法
## 初始化
```
--见example.lua
local ioc = require 'ioc'
local mod = ioc.require 'mod'		--使用ioc.requre代替require
ioc.provide('$LOG', trace)			--提供注入实例
ioc.resolveAll()					--在你认为的程序启动处，调用注入解析

mod.output('aaa')					--正常逻辑
```

## 注入变量
使用inject函数创建upvalue变量
由inject创建的upvalue变量，会在ioc.resolveAll时替换成程序提供的具体值
```
local Debug ={
	Log = inject '$LOG',
	Warnning = inject '$WARNNING',
	Error = inject '$ERROR',
}
```

## 延迟求值
使用using{key = lazy 'name'}
由using-lazy创建的变量，将在首次使用变量时求值/固化
```
using{
	print = lazy '_G.print',
	debug = lazy '_G.debug',
}
```
