package main

import (
	"encoding/json"
	"fmt"
	"net/url"
)

type Vmess struct {
	ImportBase
}

func (s *Vmess) doImport(uri string, subKey string) (item ServerItem) {
	s.subKey = subKey
	// 解析url(base64加密)
	s.decodeBaseUrl(uri)
	// 解析参数出错
	if s.err != nil {
		return
	}
	// 解析json
	var vmessType2 VmessType2
	var err error
	err = json.Unmarshal([]byte(s.opaque), &vmessType2)
	if err == nil {
		item = s.parseType2(vmessType2)
	} else {
		item = s.parseType1()
	}
	return
}

/**
  vmess://base64(security:uuid@host:port)?[urlencode(parameters)]
  其中 base64、urlencode 为函数，security 为加密方式，parameters 是以 & 为分隔符的参数列表，例如：network=kcp&aid=32&remark=服务器1 经过 urlencode 后为 network=kcp&aid=32&remark=%E6%9C%8D%E5%8A%A1%E5%99%A81
  可选参数（参数名称不区分大小写）：
  network - 可选的值为 "tcp"、 "kcp"、"ws"、"h2" 等
  wsPath - WebSocket 的协议路径
  wsHost - WebSocket HTTP 头里面的 Host 字段值
  kcpHeader - kcp 的伪装类型
  uplinkCapacity - kcp 的上行容量
  downlinkCapacity - kcp 的下行容量
  h2Path - h2 的路径
  h2Host - h2 的域名
  aid - AlterId
  tls - 是否启用 TLS，为 0 或 1
  allowInsecure - TLS 的 AllowInsecure，为 0 或 1
  tlsServer - TLS 的服务器端证书的域名
  remark - 备注名称
  导入配置时，不在列表中的参数一般会按照 Core 的默认值处理。
*/

func (s *Vmess) parseType1() (item ServerItem) {
	// todo: 解析vmess://base64(security:uuid@host:port)?[urlencode(parameters)]
	item.Type = "vmess"
	item.Url = s.uri
	item.Remark = s.remark
	item.Address = s._uri.Host
	item.Port = ToInt(s._uri.Port())
	if s._uri.User != nil {
		// vmess://security:uuid@host:port
		if pass, ok := s._uri.User.Password(); ok {
			item.Security = s._uri.User.Username()
			item.MixId = pass
		} else {
			// vmess://uuid@host:port
			item.MixId = s._uri.User.Username()
		}
	}
	params, _ := url.ParseQuery(s.query)
	fmt.Println("params", params)
	// params
	for k := range params {
		switch k {
		case "network":
			item.Network = params.Get(k)
		case "h2path":
			item.Path = params.Get(k)
		case "h2host":
			item.RequestHost = params.Get(k)
		case "host":
			item.RequestHost = params.Get(k)
		case "path":
			item.Path = params.Get(k)
		case "aid":
			item.AlterId = ToInt(params.Get(k))
		case "tls":
			if params.Get(k) == "1" {
				item.StreamSecurity = "tls"
			} else if params.Get(k) == "0" {
				item.StreamSecurity = "none"
			} else {
				item.StreamSecurity = params.Get(k)
			}
		case "security":
			item.StreamSecurity = params.Get(k)
		case "allowInsecure":
			item.AllowInsecure = params.Get(k)
		case "tlsServer":
			item.Sni = params.Get(k)
		case "sni":
			item.Sni = params.Get(k)
		case "fp":
			item.Fingerprint = params.Get(k)
		case "type":
			item.Network = params.Get(k)
		case "alpn":
			item.Alpn = params.Get(k)
		case "encryption":
			item.Security = params.Get(k)
		case "kcpHeader":
			// type 是所有传输方式的伪装类型
			item.HeaderType = params.Get(k)
		case "uplinkCapacity":
		case "downlinkCapacity":
		case "remark":
			item.Remark, _ = url.QueryUnescape(params.Get(k))
		default:
		}
	}
	fmt.Println("vmess", ToJson(item))
	if item.Remark == "" {
		item.Remark = item.Address
	}
	return item
}

/*
分享的链接（二维码）格式：vmess://(Base64编码的json格式服务器数据
json数据如下
{
"params.Get(k)": "2",
"ps": "备注别名",
"add": "111.111.111.111",
"port": "32000",
"id": "1386f85e-657b-4d6e-9d56-78badb75e1fd",
"aid": "100",
"net": "tcp",
"type": "none",
"host": "www.bbb.com",
"path": "/",
"tls": "tls"
}
params.Get(k):配置文件版本号,主要用来识别当前配置
net ：传输协议（tcp\kcp\ws\h2)
type:伪装类型（none\http\srtp\utp\wechat-video）
host：伪装的域名
1)http host中间逗号(,)隔开
2)ws host
3)h2 host
path:path(ws/h2)
tls：底层传输安全（tls)
*/

type VmessType2 struct {
	V    any    `json:"params.Get(k)"` // 类型不确定
	Ps   string `json:"ps"`
	Add  string `json:"add"`
	Port any    `json:"port"` // 类型不确定
	Id   string `json:"id"`
	Aid  any    `json:"aid"` // 类型不确定
	Type string `json:"type"`
	Scy  string `json:"scy"`
	Net  string `json:"net"`
	Host string `json:"host"`
	Path string `json:"path"`
	Tls  string `json:"tls"`
	Sni  string `json:"sni"`
	Alpn string `json:"alpn"`
	Fp   string `json:"fp"`
}

func (s *Vmess) parseType2(input VmessType2) (item ServerItem) {
	item.Type = "vmess"
	item.Url = s.uri
	item.Remark = input.Ps
	item.Address = input.Add
	item.Port = ToInt(input.Port)
	item.MixId = input.Id
	item.AlterId = ToInt(input.Aid)
	item.Security = input.Scy
	item.Network = input.Net
	item.Path = input.Path
	item.RequestHost = input.Host
	item.HeaderType = input.Type
	item.StreamSecurity = input.Tls
	item.Sni = input.Sni
	item.Alpn = input.Alpn
	item.Fingerprint = input.Fp
	if item.HeaderType == "" {
		item.HeaderType = "none"
	}
	if item.Sni == "" {
		item.Sni = item.Address
	}
	if len(item.Remark) == 0 {
		item.Remark = s.remark
	}
	fmt.Println("vmess", ToJson(item))
	s.saveImport(item)
	return item
}
