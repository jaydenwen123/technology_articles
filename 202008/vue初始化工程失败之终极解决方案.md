# vue初始化工程失败之终极解决方案

## 1. vue 初始化项目时，通常采用下列命令初始化



```shell
vue init hello
```
但是得到的效果却依然是下载模板失败

```shell
➜  ~/VueWorkspace vue init hello

? Generate project in current directory? Yes
⠦ downloading template
```

最终报错如下：

```shell
➜  ~/VueWorkspace vue init hello

? Generate project in current directory? Yes
   vue-cli · Failed to download repo vuejs-templates/hello: tunneling socket could not be established, cause=connect EHOSTUNREACH 0.0.49.95:80 - Local (10.65.89.108:56797)

➜  ~/VueWorkspace 
```

## 2. 终极解决方案

### 2.1 从github下载初始化模板

在https://github.com/vuejs-templates/ 项目首页找到webpack-simple项目复制其git链接，然后再本地下载  

> //下载webpack-simple 或 webpack.这里建议webpack-simple。因为webpack有坑。解决方案后续再更吧= =。类似严格模式（类似！！！！），多一个空格都报错的那种恶心东西


```shell
github项目首页：https://github.com/vuejs-templates/

在~/.vue-templates目录下执行如下命令
 cd ~/.vue-templates
 
 git clone https://github.com/vuejs-templates/webpack-simple.git 
```

### 2.2 初始化时指定模板

```shell
vue init webpack-simple  weibo_frontend  --offline
```

### 2.3 顺利解决问题

```shell
➜  ~/VueWorkspace vue init webpack-simple hello --offline
> Use cached template at ~/.vue-templates/webpack-simple

? Target directory exists. Continue? Yes
? Project name hello
? Project description A Vue.js project
? Author jaydenwen <jaydenwen@tencent.com>
? License MIT
? Use sass? No

   vue-cli · Generated "hello".

   To get started:
   
     cd hello
     npm install
     npm run dev

➜  ~/VueWorkspace 
```