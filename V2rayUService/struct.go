package main

import "fmt"

type ConfigInfo struct {
	Id  int32  `json:"_id,omitempty"`
	Key string `json:"key,omitempty"`
	Val string `json:"val,omitempty"`
}

type Routing struct {
	Id             int32  `json:"_id,omitempty"`
	Remark         string `json:"remark,omitempty"`
	Url            string `json:"url,omitempty"`
	RuleSet        string `json:"ruleSet,omitempty"`
	RuleNum        int32  `json:"ruleNum,omitempty"`
	Enabled        int32  `json:"enabled,omitempty"`
	Locked         int32  `json:"locked,omitempty"`
	CustomIcon     string `json:"customIcon,omitempty"`
	DomainStrategy string `json:"domainStrategy,omitempty"`
	Sort           int32  `json:"sort,omitempty"`
}

type ServerItem struct {
	Id             int32  `json:"_id,omitempty"`            // 自增id
	Key            string `json:"key,omitempty"`            // server key
	SubKey         string `json:"sub_key,omitempty"`        // 订阅key
	Type           string `json:"type,omitempty"`           // server type: vmess|vless|trojan|ss|ssr|
	Remark         string `json:"remark,omitempty"`         // remark
	Speed          int    `json:"speed"`                    // speed
	Url            string `json:"url,omitempty"`            // share url | import url
	Json           string `json:"json,omitempty"`           // v2ray-json
	Address        string `json:"address,omitempty"`        // host
	Port           int    `json:"port,omitempty"`           // port
	MixId          string `json:"id,omitempty"`             // vmess id | vless id | trojan password | ss password | ssr password
	AlterId        int    `json:"alterId,omitempty"`        // vmess alterId | vless alterId
	Security       string `json:"security,omitempty"`       // encryption method: aes-128-gcm | chacha20-poly1305 | auto
	Network        string `json:"network,omitempty"`        // network: tcp|ws|h2|grpc|kcp|quic
	HeaderType     string `json:"headerType,omitempty"`     // header-type: tcp=none;ws=none;http=none;grpc=multi;[quic|kcp]=[srtp|utp|wechat-video|dtls|wireguard]
	RequestHost    string `json:"requestHost,omitempty"`    // requestHost: ws host | h2 host
	Path           string `json:"path,omitempty"`           // path: ws path | h2 path | grpc serviceName | http path | kcp seed
	StreamSecurity string `json:"streamSecurity,omitempty"` // stream-security: tls|xtls|reality|none
	AllowInsecure  string `json:"allowInsecure,omitempty"`  // allowInsecure
	Flow           string `json:"flow,omitempty"`           // flow: xtls-flow
	Sni            string `json:"sni,omitempty"`            // sni: serverName
	Alpn           string `json:"alpn,omitempty"`           // alpn: h2,http/1.1
	Fingerprint    string `json:"fingerprint,omitempty"`    // fingerprint: chrome
	PublicKey      string `json:"publicKey,omitempty"`      // vless-reality: publicKey
	ShortId        string `json:"shortId,omitempty"`        // vless-reality: shortId
	SpiderX        string `json:"spiderX,omitempty"`        // vless-reality: spiderX
}

type ServerStat struct {
	Id        string `json:"_id,omitempty"`
	TotalUp   int32  `json:"totalUp,omitempty"`
	TotalDown int32  `json:"totalDown,omitempty"`
	TodayUp   int32  `json:"todayUp,omitempty"`
	TodayDown int32  `json:"todayDown,omitempty"`
	DateNow   int32  `json:"dateNow,omitempty"`
}

type SubItem struct {
	Id                 int32  `json:"_id,omitempty"`
	Key                string `json:"key,omitempty"`
	SubType            string `json:"sub_type,omitempty"`
	Remark             string `json:"remark,omitempty"`
	Url                string `json:"url,omitempty"`
	Enabled            int32  `json:"enabled,omitempty"`
	Sort               int32  `json:"sort,omitempty"`
	AutoUpdateInterval int32  `json:"auto_update_interval,omitempty"`
	UpdateTime         int32  `json:"update_time,omitempty"`
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

func (s *ServerItem) updateSpeed(speed int) {
	if speed == 0 {
		s.Speed = -1
	}
	_, err := db.Exec("UPDATE server_item SET speed=? WHERE _id=?", speed, s.Id)
	if err != nil {
		fmt.Println("updateSpeed err", err)
	}
}

func (s *ServerItem) updateSpeedByTotalUp(totalUp int) {}
