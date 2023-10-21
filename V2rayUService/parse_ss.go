package main

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"strings"
)

type SS struct {
	ImportBase
}

func (s *SS) doImport(uri string, subKey string) (item ServerItem) {
	s.subKey = subKey
	s.decodeBaseUrl(uri)
	if s.err != nil {
		return
	}
	fmt.Println("_url", ToJson(s._uri))
	item.Type = "ss"
	item.Url = uri
	item.Network = "tcp"
	item.HeaderType = "none"
	item.Remark = s.remark // # 后面的内容
	// 地址及端口
	hostPort := strings.Split(s._uri.Host, ":")
	item.Address = hostPort[0]
	if len(hostPort) > 1 {
		item.Port = ToInt(hostPort[1])
	}
	// 密码及加密方法部分(base64加密)
	encodeStr := s._uri.User.String()
	fmt.Println("encodeStr", s._uri.User)
	decodeStr, err := base64.URLEncoding.DecodeString(encodeStr)
	if err != nil {
		fmt.Println("decodeStr, err", string(decodeStr), err)
		// try RawURLEncoding
		decodeStr, err = base64.RawURLEncoding.DecodeString(encodeStr)
		if err != nil {
			fmt.Println("decodeStr, err", string(decodeStr), err)
		}
	}
	methodPass := strings.Split(string(decodeStr), ":")
	item.Security = methodPass[0]
	if len(methodPass) > 1 {
		item.MixId = methodPass[1]
	}
	fmt.Println("ss", ToJson(item))
	s.saveImport(item)
	return
}

type SSR struct {
	ImportBase
}

// link: https://coderschool.cn/2498.html
// ssr://server:port:protocol:method:obfs:password_base64/?params_base64
// 上面的链接的不同之处在于 password_base64 和 params_base64 ，顾名思义，password_base64 就是密码被 base64编码 后的字符串，而 params_base64 则是协议参数、混淆参数、备注及Group对应的参数值被 base64编码 后拼接而成的字符串。

func (s *SSR) doImport(uri string, subKey string) (item ServerItem) {
	if uri == "" {
		return
	}
	s.subKey = subKey
	s.decodeBaseUrl(uri)
	body := strings.TrimPrefix(uri, "ssr://")
	body = strings.Split(body, "#")[0]
	body = strings.Split(body, "/?")[0]
	body = tryDecodeBase64(body)
	var paramStr string
	// 判断base64解码后的字符串是否包含 /? 字符串
	if strings.Contains(body, "/?") {
		// 情况1. server:port:protocol:method:obfs:password_base64/?params_base64
		split := strings.Split(body, "/?")
		body = split[0]
		paramStr = split[1]
	} else {
		// 情况2. server:port:protocol:method:obfs:password_base64
		if strings.Contains(uri, "/?") {
			paramStr = strings.Split(uri, "/?")[1]
		}
	}
	// 解析 body 部分, 以 : 分割
	groups := strings.Split(body, ":")
	if len(groups) < 5 {
		fmt.Println("body groups len < 5")
		return
	}
	item.Url = uri
	item.Type = "ssr"
	item.Network = "tcp"
	item.HeaderType = "none"
	item.Address = groups[0]
	item.Port = ToInt(groups[1])
	item.Security = groups[3]
	item.MixId = tryDecodeBase64(groups[5]) // 密码 password_base64
	// 解析 params_base64
	if len(paramStr) > 0 {
		paramStr = tryDecodeBase64(paramStr)
		params, err := url.ParseQuery(paramStr)
		if err == nil {
			for key := range params {
				// remark
				if key == "Remark" || key == "remark" || key == "remarks" {
					item.Remark = params.Get(key)
				}
			}
		}
	}
	// remark
	if len(item.Remark) == 0 {
		if strings.Contains(uri, "#") {
			item.Remark = strings.Split(uri, "#")[1]
		} else {
			item.Remark = item.Address
		}
	}
	fmt.Println("ssr", ToJson(item))
	s.saveImport(item)
	return
}
