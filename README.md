# V2rayU
![](https://github.com/yanue/V2rayU/blob/master/V2rayU/Assets.xcassets/AppIcon.appiconset/128.png?raw=true)

V2rayU 是一款v2ray mac客户端,用于科学上网,使用swift4.2编写,基于v2ray项目,支持vmess,shadowsocks,socks5等服务协议(推荐搭建**v2ray服务**,可伪装成正常网站,防封锁), 支持二维码,剪贴板导入,手动配置,二维码分享等, 支持订阅, 项目地址: https://github.com/yanue/V2rayU

### 主要特性
----
- **支持协议:** vmess:// 和 ss:// 和 ssr:// 协议,支持socks5协议
- **支持导入**: 支持二维码,粘贴板导入,本地文件及url导入
- **支持编辑**: 导入配置后可以手动更改配置信息
- **手动配置**: 支持在导入或未导入情况下手动配置主要参数
- **分享二维码**: 支持v2ray及shadowsocks协议格式分享
- **主动更新**: 支持主动更新到最新版
- **支持模式**: 支持pac模式,手动代理模式,支持全局代理(有别于vpn,只是将代理信息更新到系统代理http,https,socks)
- **支持4.0**: 支持手动切换到v2ray-core 4.0以上配置格式
- **支持订阅**: <span style="color: red">支持v2ray和ss及ssr订阅</span>

### 下载安装
- 方式一: 使用homebrew命令安装
```
  brew cask install v2rayu
```
- 方式二: 下载最新版安装
> [https://github.com/yanue/V2rayU/releases](https://github.com/yanue/V2rayU/releases)

### v2ray简介
   V2Ray 是 Project V 下的一个工具。Project V 包含一系列工具，帮助你打造专属的定制网络体系。而 V2Ray 属于最核心的一个。
简单地说，V2Ray 是一个与 Shadowsocks 类似的代理软件，但比Shadowsocks更具优势

V2Ray 用户手册：[https://www.v2ray.com](https://www.v2ray.com)

V2Ray 项目地址：[https://github.com/v2ray/v2ray-core](https://github.com/v2ray/v2ray-core)

### 功能预览
----
<p>
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/menu.png?raw=true" height="300"/> 
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/share.png?raw=true" height="300"/> 
    <img src="https://github.com/yanue/V2rayU/blob/master/screenshot/about.png?raw=true" height="300"/> 
</p>
<p>
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/import.png?raw=true" width="400"/> 
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/manual.png?raw=true"  width="400"/>
</p>
<p>
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/general.png?raw=true" height="300"/> 
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/advance.png?raw=true" height="300"/> 
</p>
<p>
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/subscribe.png?raw=true" height="300"/> 
	<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/pac.png?raw=true" height="300"/> 
</p>

### v2ray服务器搭建推荐

v2ray配置指南: [https://toutyrater.github.io/](https://toutyrater.github.io/)

Caddy+h2脚本: [https://github.com/dylanbai8/V2Ray_h2-tls_Website_onekey.git](https://github.com/dylanbai8/V2Ray_h2-tls_Website_onekey.git)

v2ray模板: [https://github.com/KiriKira/vTemplate](https://github.com/KiriKira/vTemplate)

### 代理模式
	全局模式: 有别于vpn,只是将代理信息更新到系统代理http,https,socks,若需要真正全局模式, 推荐搭配使用Proxifier
	rules模式: 浏览器推荐搭配使用Proxy SwitchyOmega

### 相关文件
	v2ray-core文件: /Applications/V2rayU.app/Contents/Resources/v2ray-core
	v2ray-core启动: ~/Library/LaunchAgents/yanue.v2rayu.v2ray-core.plist
	v2ray-core日志: ~/Library/Logs/V2rayU.log
	当前启动服务配置: /Applications/V2rayU.app/Contents/Resources/config.json
	其他服务配置信息: ~/Library/Preferences/net.yanue.V2rayU.plist


	如果启动无反应可以尝试从命令行手动启动,查看原因
```
cd /Applications/V2rayU.app/Contents/Resources/
./v2ray-core/v2ray -config ./config.json
```

### 相关问题
**1. 闪退**

> 大多因为读取配置文件问题,删除以下文件重新配置即可

```
 ~/Library/Preferences/net.yanue.V2rayU.plist
```
另外, 可以通过 command + 空格 搜索 console.app , 打开后搜索 V2rayU 定位具体闪退错误日志

 **2. 无法启动v2ray服务**

> 多数情况为端口被占用,可以通过 show logs... 查看日志进行排查, 如端口被占用,请更改后重试

 **3. 正常启动却无法翻墙访问**

> 确保配置是正确的,然后确认启动的模式,在到网络->高级里面查看是否写入对应的代理信息(manual模式需要配合浏览器插件使用)

**4. 报错: open config.json: no such file or directory**

> 请严格按照 dmg 文件,拖动到 Applications 里面试下

### 问题排查方法

1. 不能使用
>  如果之前有用过,更新或更改配置导致不能使用, 请彻底卸载试下,包含上面的相关文件(推荐使用appcleaner)
   
2. 无法启动或启动后无法翻墙: 
  ##### a. 检查配置是否正确(主要是outbound和stream)
  ##### b. 查看日志
```
	v2ray自身日志: V2rayU -> Show logs...
	V2rayU日志: command + 空格 搜索 console.app , 打开后搜索 V2rayU 定位错误日志
```
  #####   c. 手动启动
```
cd /Applications/V2rayU.app/Contents/Resources/
./v2ray-core/v2ray -config ./config.json
```
  #####  d. 查看网络配置: 启动V2rayU后查看: 网络 -> 高级 -> 代理 是否生效

  #####  e. 以上都解决不了,提交issue

### 待实现功能:
	中文
	路由规则配置
	速度测试
	
### 欢迎贡献代码:
	1. fork 然后 git clone
	2. pod install
	3. 下载最新版v2ray-core,如: https://github.com/v2ray/v2ray-core/releases/download/v4.8.0/v2ray-macos.zip,解压到Build目录,重命名为v2ray-core
	4. 运行xcode即可

### 软件使用问题
	1. 安装包显示文件已损坏的解决方案: sudo spctl --master-disable
	2. 如果启动后代理无效,请查看日志,入口: 菜单 -> Show logs...
	3. 有其他问题请提issue

### 感谢
	参考: ShadowsocksX-NG V2RayX
	logo: @小文

### License
	GPLv3
