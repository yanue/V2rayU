# V2rayU
![](https://github.com/yanue/V2rayU/blob/master/V2rayU/Assets.xcassets/AppIcon.appiconset/128.png?raw=true)

V2rayU 是一款v2ray mac客户端,用于科学上网,使用swift4.2编写,基于v2ray项目,支持vmess,shadowsocks,socks5等服务协议, 支持二维码,剪贴板导入,手动配置,二维码分享等

### 主要特性
----
- **支持协议:** vmess:// 和 ss:// 协议,支持socks5协议
- **支持导入**: 支持二维码,粘贴板导入,本地文件及url导入
- **支持编辑**: 导入配置后可以手动更改配置信息
- **手动配置**: 支持在导入或未导入情况下手动配置主要参数
- **分享二维码**: 支持v2ray及shadowsocks协议格式分享
- **主动更新**: 支持主动更新到最新版
- **全局模式**: 支持全局代理(有别于vpn,只是将代理信息更新到系统代理http,https,socks)

### v2ray简介
   V2Ray 是 Project V 下的一个工具。Project V 包含一系列工具，帮助你打造专属的定制网络体系。而 V2Ray 属于最核心的一个。
简单地说，V2Ray 是一个与 Shadowsocks 类似的代理软件，但比Shadowsocks更具优势

V2Ray 用户手册：[https://www.v2ray.com](https://www.v2ray.com)

V2Ray 项目地址：[https://github.com/v2ray/v2ray-core](https://github.com/v2ray/v2ray-core)

### 功能预览
----
<p>
<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/1.png?raw=true" height="300"/> 
<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/4.png?raw=true" height="300"/> 
<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/5.png?raw=true" height="300"/> 
</p>
<p>

<img src="https://github.com/yanue/V2rayU/blob/master/screenshot/2.png?raw=true" width="400"/> <img src="https://github.com/yanue/V2rayU/blob/master/screenshot/3.png?raw=true"  width="400"/>
</p>

### v2ray服务器搭建推荐

Caddy+h2脚本: [https://github.com/dylanbai8/V2Ray_h2-tls_Website_onekey.git](https://github.com/dylanbai8/V2Ray_h2-tls_Website_onekey.git)

v2ray模板: [https://github.com/KiriKira/vTemplate](https://github.com/KiriKira/vTemplate)

### 代理模式
	全局模式: 有别于vpn,只是将代理信息更新到系统代理http,https,socks,若需要真正全局模式, 推荐搭配使用Proxifier
	rules模式: 浏览器推荐搭配使用Proxy SwitchyOmega

### 软件使用问题
	1. 安装包显示文件已损坏的解决方案: sudo spctl --master-disable
	2. 有其他问题请提issue

### 感谢
	参考: ShadowsocksX-NG V2RayX
	logo: @小文

### License
	GPLv3