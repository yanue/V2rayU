package main

import "C"
import (
	"fmt"
	"gopkg.in/yaml.v3"
)

type Clash struct {
	ImportBase
	subKey string
}

type ClashConfig struct {
	Proxy []map[string]any `yaml:"proxies"`
}

func (s *Clash) doImport(uri string, subKey string) {
	s.subKey = subKey
	var clash ClashConfig
	err := yaml.Unmarshal([]byte(uri), &clash)
	if err != nil {
		fmt.Println("err", err)
		return
	}
	for _, cfg := range clash.Proxy {
		s.importByMap(cfg)
	}
	return
}

func (s *Clash) importByMap(cfg map[string]any) (item ServerItem) {
	item.SubKey = s.subKey
	item.Type = getMapString(cfg, "type")
	item.Remark = getMapString(cfg, "name")
	item.Address = getMapString(cfg, "server")
	item.Sni = getMapString(cfg, "sni")
	item.Port = ToInt(cfg["port"])
	switch cfg["type"] {
	case "trojan":
		item.MixId = getMapString(cfg, "password")
		item.Network = "tcp"
		item.HeaderType = "none"
	case "vmess":
		item.MixId = getMapString(cfg, "uuid")
		item.Security = getMapString(cfg, "cipher")
		item.Network = getMapString(cfg, "network")
		item.AlterId = ToInt(cfg["alterId"])
		switch item.Network {
		case "ws":
			if opts, ok := cfg["ws-opts"].(map[string]any); ok {
				if hosts, _ok := opts["host"].([]string); _ok && len(hosts) > 0 {
					item.RequestHost = hosts[0]
				}
				item.Path = getMapString(opts, "path")
			}
		case "h2":
			if opts, ok := cfg["h2-opts"].(map[string]any); ok {
				item.Path = getMapString(opts, "path")
				if hosts, _ok := opts["host"].([]string); _ok && len(hosts) > 0 {
					item.RequestHost = hosts[0]
				}
			}
		case "grpc":
			if opts, ok := cfg["grpc-opts"].(map[string]any); ok {
				item.Path = getMapString(opts, "grpcServiceName")
			}
		}
		// 检查
		if item.RequestHost == "" {
			item.RequestHost = item.Address
		}
		if item.Sni == "" {
			item.Sni = item.Address
		}
		if item.StreamSecurity == "" {
			item.StreamSecurity = "tls"
		}
	case "vless":
		item.MixId = getMapString(cfg, "uuid")
		item.Security = getMapString(cfg, "cipher")
		item.Network = getMapString(cfg, "network")
		item.AlterId = ToInt(cfg["alterId"])
		switch item.Network {
		case "ws":
			if opts, ok := cfg["ws-opts"].(map[string]any); ok {
				if hosts, _ok := opts["host"].([]string); _ok && len(hosts) > 0 {
					item.RequestHost = hosts[0]
				}
				item.Path = getMapString(opts, "path")
			}
		case "h2":
			if opts, ok := cfg["h2-opts"].(map[string]any); ok {
				item.Path = getMapString(opts, "path")
				if hosts, _ok := opts["host"].([]string); _ok && len(hosts) > 0 {
					item.RequestHost = hosts[0]
				}
			}
		case "grpc":
			if opts, ok := cfg["grpc-opts"].(map[string]any); ok {
				item.Path = getMapString(opts, "grpcServiceName")
			}
		case "reality":
			if opts, ok := cfg["reality-opts"].(map[string]any); ok {
				item.PublicKey = getMapString(opts, "publicKey")
				item.ShortId = getMapString(opts, "shortId")
				item.SpiderX = getMapString(opts, "spiderX")
			}
		}
		if item.RequestHost == "" {
			item.RequestHost = item.Address
		}
		if item.Sni == "" {
			item.Sni = item.Address
		}
		if item.StreamSecurity == "" {
			item.StreamSecurity = "tls"
		}
	case "ss":
		item.MixId = getMapString(cfg, "password")
		item.Security = getMapString(cfg, "cipher")
		item.Network = "tcp"
		item.HeaderType = "none"

	case "ssr":
		item.MixId = getMapString(cfg, "password")
		item.Security = getMapString(cfg, "cipher")
		item.Network = "tcp"
		item.HeaderType = "none"
		return
	}
	fmt.Println("item", ToJson(item))
	s.saveImport(item)
	return
}

func getMapString(cfg map[string]any, field string) string {
	val, ok := cfg[field]
	if ok {
		switch val.(type) {
		case string:
			return cfg[field].(string)
		default:
			return fmt.Sprint(cfg[field])
		}
	}
	return ""
}

/**
- {"type":"ss","name":"v2rayse_test_1","server":"198.57.27.218","port":5004,"cipher":"aes-256-gcm","password":"g5MeD6Ft3CWlJId"}
- {"type":"ssr","name":"v2rayse_test_3","server":"20.239.49.44","port":59814,"protocol":"origin","cipher":"dummy","obfs":"plain","password":"3df57276-03ef-45cf-bdd4-4edb6dfaa0ef"}
- {"type":"vmess","name":"v2rayse_test_2","ws-opts":{"path":"/"},"server":"154.23.190.162","port":443,"uuid":"b9984674-f771-4e67-a198-","alterId":"0","cipher":"auto","network":"ws"}
- {"type":"vless","name":"test","server":"1.2.3.4","port":7777,"uuid":"abc-def-ghi-fge-zsx","skip-cert-verify":true,"network":"tcp","tls":true,"udp":true}
- {"type":"trojan","name":"v2rayse_test_4","server":"ca-trojan.bonds.id","port":443,"password":"bc7593fe-0604-4fbe--b4ab-11eb-b65e-1239d0255272","udp":true,"skip-cert-verify":true}
- {"type":"http","name":"http_proxy","server":"124.15.12.24","port":251,"username":"username","password":"password","udp":true}
- {"type":"socks5","name":"socks5_proxy","server":"124.15.12.24","port":2312,"udp":true}
- {"type":"socks5","name":"telegram_proxy","server":"1.2.3.4","port":123,"username":"username","password":"password","udp":true}
*/
