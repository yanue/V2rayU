package main

import (
	"fmt"
)

type Vless struct {
	ImportBase
}

func (s *Vless) doImport(uri string, subKey string) (item ServerItem) {
	s.subKey = subKey
	s.decodeBaseUrl(uri)
	if s.err != nil {
		return
	}
	item.Type = "vless"
	item.Address = s._uri.Host
	item.Port = ToInt(s._uri.Port())
	if s._uri.User != nil {
		item.MixId = s._uri.User.Username()
	}
	values := s._uri.Query()
	item.Network = values.Get("type") // network: tcp|ws|h2
	item.RequestHost = values.Get("host")
	item.Path = values.Get("path")
	item.Flow = values.Get("flow")
	item.Security = values.Get("encryption")     // encryption: none|aes-128-gcm|chacha20-poly1305|auto
	item.StreamSecurity = values.Get("security") // tls|xtls|reality|none
	item.Fingerprint = values.Get("fp")
	item.PublicKey = values.Get("pbk")
	item.ShortId = values.Get("sid")
	item.Sni = values.Get("sni")
	if len(item.StreamSecurity) == 0 {
		item.StreamSecurity = "tls"
	}
	if len(item.Sni) == 0 {
		item.Sni = item.Address
	}
	if len(item.Fingerprint) == 0 {
		item.Fingerprint = "chrome"
	}
	item.Remark = s.remark // # 后面的内容
	item.Url = uri
	fmt.Println("vless", ToJson(item))
	s.saveImport(item)
	return ServerItem{}
}
