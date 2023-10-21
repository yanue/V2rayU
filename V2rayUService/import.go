package main

import (
	"fmt"
	"log"
	"net/url"
	"strings"
	"time"
)

// 待定标准方案: https://github.com/XTLS/Xray-core/issues/91
//# VMess + TCP，不加密（仅作示例，不安全）
//vmess://99c80931-f3f1-4f84-bffd-6eed6030f53d@qv2ray.net:31415?encryption=none#VMessTCPNaked
//# VMess + TCP，自动选择加密。编程人员特别注意不是所有的 URL 都有问号，注意处理边缘情况。
//vmess://f08a563a-674d-4ffb-9f02-89d28aec96c9@qv2ray.net:9265#VMessTCPAuto
//# VMess + TCP，手动选择加密
//vmess://5dc94f3a-ecf0-42d8-ae27-722a68a6456c@qv2ray.net:35897?encryption=aes-128-gcm#VMessTCPAES
//# VMess + TCP + TLS，内层不加密
//vmess://136ca332-f855-4b53-a7cc-d9b8bff1a8d7@qv2ray.net:9323?encryption=none&security=tls#VMessTCPTLSNaked
//# VMess + TCP + TLS，内层也自动选择加密
//vmess://be5459d9-2dc8-4f47-bf4d-8b479fc4069d@qv2ray.net:8462?security=tls#VMessTCPTLS
//# VMess + TCP + TLS，内层不加密，手动指定 SNI
//vmess://c7199cd9-964b-4321-9d33-842b6fcec068@qv2ray.net:64338?encryption=none&security=tls&sni=fastgit.org#VMessTCPTLSSNI
//# VLESS + TCP + XTLS
//vless://b0dd64e4-0fbd-4038-9139-d1f32a68a0dc@qv2ray.net:3279?security=xtls&flow=rprx-xtls-splice#VLESSTCPXTLSSplice
//# VLESS + mKCP + Seed
//vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:50288?type=kcp&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeed
//# VLESS + mKCP + Seed，伪装成 Wireguard
//vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:41971?type=kcp&headerType=wireguard&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeedWG
//# VMess + WebSocket + TLS
//vmess://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:6939?type=ws&security=tls&host=qv2ray.net&path=%2Fsomewhere#VMessWebSocketTLS
//# VLESS + TCP + reality
//vless://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=sni.yahoo.com&fp=chrome&pbk=xxx&sid=88&type=tcp&headerType=none&host=hk.yahoo.com#reality

var serverImport = new(ServerImport)

type ServerImport struct {
}

func (s *ServerImport) importBySub(txt string, sub *SubItem) {
	txt = strings.Trim(txt, " ")
	txt = tryDecodeBase64(txt)
	if s.supportProtocol(txt) {
		s.importNormal(txt, sub.Key)
	} else {
		s.importClash(txt, sub.Key)
	}
}

func (s *ServerImport) importNormal(txt string, subKey string) {
	fmt.Println("importNormal")
	lines := strings.Split(txt, "\n")
	for _, line := range lines {
		s.doImport(line, subKey)
	}
}

func (s *ServerImport) importClash(txt string, subKey string) {
	fmt.Println("importClash")
	new(Clash).doImport(txt, subKey)
}

func (s *ServerImport) supportProtocol(uri string) bool {
	if strings.HasPrefix(uri, "ss://") || strings.HasPrefix(uri, "ssr://") || strings.HasPrefix(uri, "vmess://") || strings.HasPrefix(uri, "vless://") || strings.HasPrefix(uri, "trojan://") {
		return true
	}
	return false
}

func (s *ServerImport) doImport(uri string, subKey string) {
	if strings.HasPrefix(uri, "trojan://") {
		new(Trojan).doImport(uri, subKey)
	}
	if strings.HasPrefix(uri, "ssr://") {
		new(SSR).doImport(uri, subKey)
	}
	if strings.HasPrefix(uri, "ss://") {
		new(SS).doImport(uri, subKey)
	}
	if strings.HasPrefix(uri, "vmess://") {
		new(Vmess).doImport(uri, subKey)
	}
	if strings.HasPrefix(uri, "vless://") {
		new(Vless).doImport(uri, subKey)
	}
}

type ImportBase struct {
	_uri   *url.URL
	err    error
	uri    string // 原始url
	subKey string
	opaque string // (已做base64解析)中间: 大部分base64(地址:端口)
	query  string // ? 后面的query参数
	remark string // # Fragment
	item   ServerItem
}

// 大部分地址都是 协议://base64(地址:端口)#备注
func (s *ImportBase) decodeBaseUrl(uri string) {
	uri = strings.Trim(uri, " ")
	s.uri = uri
	if uri == "" {
		return
	}
	s._uri, s.err = url.Parse(uri)
	if s.err != nil {
		fmt.Println("url.Parse error:", s.err)
		return
	}
	s.remark = url.QueryEscape(s._uri.Fragment) // # 后面的内容
	s.query = s._uri.RawQuery                   // ? 后面的query参数
	s.opaque = tryDecodeBase64(s._uri.Host)     // base64 解密

	return
}

func (s *ImportBase) saveImport(item ServerItem) {
	fields := []string{
		`key`, `sub_key`, `type`, `remark`, `speed`, `url`, `json`, `address`, `port`, `id`,
		`alterId`, `security`, `network`, `headerType`, `requestHost`, `path`, `streamSecurity`, `allowInsecure`, `flow`, `sni`,
		`alpn`, `fingerprint`, `publicKey`, `shortId`, `spiderX`,
	}
	item.Key = fmt.Sprintf("config.%v", time.Now().UnixMicro())
	item.SubKey = s.subKey
	item.Speed = -1
	var placeholder []string
	for i := 0; i < len(fields); i++ {
		placeholder = append(placeholder, "?")
	}
	_sql := fmt.Sprintf(`INSERT INTO "server_item" ("%s") VALUES (%s);`, strings.Join(fields, `","`), strings.Join(placeholder, ","))
	txn, err := db.Begin()
	if err != nil {
		log.Println("err1", err)
		return
	}
	stmt, err := txn.Prepare(_sql)
	if err != nil {
		log.Println("err2", err)
		return
	}
	res, err := stmt.Exec(
		item.Key, item.SubKey, item.Type, item.Remark, item.Speed, item.Url, item.Json, item.Address, item.Port, item.MixId,
		item.AlterId, item.Security, item.Network, item.HeaderType, item.RequestHost, item.Path, item.StreamSecurity, item.AllowInsecure, item.Flow, item.Sni,
		item.Alpn, item.Fingerprint, item.PublicKey, item.ShortId, item.SpiderX,
	)
	log.Println("res, err", res, err)
	err = txn.Commit()
	stmt.Close()
}
