package main

import (
	"encoding/json"
	"fmt"
)

type ServerToV2ray struct {
	*ServerItem
	// setting
	enableUdp      bool
	enableSniffing bool
	httpPort       int
	socksPort      int
	// v2ray config
	config *V2rayConfig
}

func (s *ServerToV2ray) toV2rayConfig(item *ServerItem) *ServerToV2ray {
	s.ServerItem = item
	s.config = new(V2rayConfig)
	// log
	s.config.Log = s.getLog()
	// api
	s.config.Api = s.getApi()
	// policy
	s.config.Policy = s.getPolicy()
	// inbounds
	s.config.Inbounds = []Inbound{s.getInboundHttp(), s.getInboundSocks(), s.getInboundDokodemoDoor()}
	// outbounds
	s.config.Outbounds = []Outbound{s.getOutbound(), s.getOutboundDirect(), s.getOutboundBlock()}
	// dns
	s.config.Dns = s.getDns()
	// routing
	s.config.Routing = s.getRouting("")
	return s
}

func (s *ServerToV2ray) getLog() V2rayLog {
	return V2rayLog{
		Access:   "",
		Error:    "",
		Loglevel: "",
		DnsLog:   false,
	}
}

func (s *ServerToV2ray) getApi() V2rayApi {
	return V2rayApi{
		Tag:      "api",
		Services: []string{"StatsService"},
	}
}

func (s *ServerToV2ray) getPolicy() V2rayPolicy {
	return V2rayPolicy{
		System: V2rayPolicyStat{StatsOutboundDownlink: true, StatsOutboundUplink: true},
	}
}

// parseInbound
func (s *ServerToV2ray) getInboundHttp() Inbound {
	inbound := Inbound{}
	inbound.Port = s.httpPort
	inbound.Listen = "127.0.0.1"
	inbound.Protocol = "http"
	inbound.Sniffing = new(InboundSniffing)
	inbound.Sniffing.Enabled = true
	inbound.Sniffing.DestOverride = []string{"http", "tls"}
	return inbound
}

func (s *ServerToV2ray) getInboundSocks() Inbound {
	inbound := Inbound{}
	inbound.Port = s.httpPort
	inbound.Listen = "127.0.0.1"
	inbound.Protocol = "socks"
	inbound.Sniffing = new(InboundSniffing)
	inbound.Sniffing.Enabled = true
	inbound.Sniffing.DestOverride = []string{"http", "tls"}
	return inbound
}

// 任意门
func (s *ServerToV2ray) getInboundDokodemoDoor() Inbound {
	inbound := Inbound{}
	inbound.Port = 9090
	inbound.Listen = "127.0.0.1"
	inbound.Protocol = "dokodemo-door"
	return inbound
}

func (s *ServerToV2ray) getDns() V2rayDNS {
	dns := V2rayDNS{}
	dns.Hosts = map[string]string{
		"dns.google": "8.8.8.8",
	}
	dnsServer := V2rayDnsServer{
		Address:   "223.5.5.5",
		Domains:   []string{"geosite:cn"},
		ExpectIPs: []string{"geoip:cn"},
	}
	dns.Servers = append(dns.Servers, dnsServer, "1.1.1.1", "8.8.8.8", "https://dns.google/dns-query")
	return dns
}

func (s *ServerToV2ray) getRouting(rules string) V2rayRouting {
	routing := V2rayRouting{}
	routing.DomainStrategy = "IPOnDemand" // AsIs | IPIfNonMatch | IPOnDemand

	err := json.Unmarshal([]byte(rules), &routing.Rules)
	if err != nil {
		fmt.Println("getRouting err", err)
		routing.Rules = s.getDefaultRouting()
	}
	return routing
}

func (s *ServerToV2ray) getDefaultRouting() []V2rayRoutingRule {
	// api rules
	apiRule := V2rayRoutingRule{
		Type:        "field",
		InboundTag:  []string{"api"},
		OutboundTag: "api",
	}

	// block ad rules
	blockAdRule := V2rayRoutingRule{
		Type:        "field",
		OutboundTag: "block",
		Domain:      []string{"geosite:category-ads-all"},
	}

	// direct geoip ip rules
	directIpRule := V2rayRoutingRule{
		Type:        "field",
		OutboundTag: "direct",
		Ip:          []string{"geoip:private", "geoip:cn"},
	}

	// direct geosite domain rules
	directGeoSiteRule := V2rayRoutingRule{
		Type:        "field",
		OutboundTag: "direct",
		Domain:      []string{"geosite:cn"},
	}

	// direct custom domain rules
	directDomainRule := V2rayRoutingRule{
		Type:        "field",
		OutboundTag: "direct",
		Domain:      []string{""},
	}

	// proxy domain rules
	proxyDomainRules := V2rayRoutingRule{
		Type:        "field",
		OutboundTag: "proxy",
		Domain:      []string{},
		Port:        "0-65535",
	}
	return []V2rayRoutingRule{apiRule, blockAdRule, directIpRule, directGeoSiteRule, directDomainRule, proxyDomainRules}
}

func (s *ServerToV2ray) getOutbound() Outbound {
	// outbounds
	outbound := Outbound{}
	outbound.Protocol = "trojan"
	outbound.Tag = "proxy"
	outbound.StreamSettings = s.parseStreamSettings()
	// 解析
	switch s.Type {
	case "trojan":
		settings := s.getTrojanConfig()
		outbound.Settings = settings
	case "vmess":
		settings := s.getVmessConfig()
		outbound.Settings = settings
	case "vless":
		settings := s.getVlessConfig()
		outbound.Settings = settings
	case "ss", "ssr":
		settings := s.getShadowsocksConfig()
		outbound.Settings = settings
	}
	return outbound
}

func (s *ServerToV2ray) getOutboundBlock() Outbound {
	settings := map[string]any{
		"response": map[string]string{
			"type": "http",
		},
	}
	return Outbound{
		Protocol: "blackhole",
		Tag:      "block",
		Settings: settings,
	}
}

func (s *ServerToV2ray) getOutboundDirect() Outbound {
	return Outbound{
		Protocol: "freedom",
		Tag:      "direct",
	}
}

func (s *ServerToV2ray) getTrojanConfig() *OutboundTrojan {
	trojan := TrojanItem{
		Address:  s.Address,
		Port:     s.Port,
		Password: s.MixId,
	}

	settings := new(OutboundTrojan)
	settings.Servers = []TrojanItem{trojan}
	return settings
}

func (s *ServerToV2ray) getVmessConfig() *OutboundVMess {
	settings := new(OutboundVMess)
	vnextUser := VMessUser{
		Id:       s.MixId,
		Security: s.Security, // aes-128-gcm | chacha20-poly1305 | auto
		AlterId:  s.AlterId,
	}
	vnext := VMessNext{
		Address: s.Address,
		Port:    s.Port,
		Users:   []VMessUser{vnextUser},
	}
	settings.Vnext = []VMessNext{vnext}
	return settings
}

func (s *ServerToV2ray) getVlessConfig() *OutboundVLess {
	settings := new(OutboundVLess)
	vnextUser := VLessUser{
		Id:         s.MixId,
		Encryption: s.Security,
		Flow:       s.Flow,
	}
	vnext := VLessNext{
		Address: s.Address,
		Port:    s.Port,
		Users:   []VLessUser{vnextUser},
	}
	settings.Vnext = []VLessNext{vnext}
	return settings
}

func (s *ServerToV2ray) getShadowsocksConfig() *OutboundShadowsock {
	// shadowsocks-outbound
	ss := ShadowsockItem{
		Address:  s.Address,
		Port:     s.Port,
		Method:   s.Security,
		Password: s.MixId,
	}

	settings := new(OutboundShadowsock)
	settings.Servers = []ShadowsockItem{ss}
	return settings
}

func (s *ServerToV2ray) parseStreamSettings() StreamSetting {
	streamSetting := StreamSetting{}
	// network: "tcp" | "kcp" | "ws" | "http" | "domainsocket" | "quic" | "grpc"
	switch s.Network {
	case "ws":
		streamSetting.Network = "ws"
		wsSetting := &WsSetting{}
		wsSetting.Path = s.Path
		wsSetting.Headers.Host = s.RequestHost
		streamSetting.WsSettings = wsSetting
	case "h2":
		streamSetting.Network = "h2"
		h2Setting := &HttpSetting{}
		h2Setting.Path = s.Path
		h2Setting.Host = []string{s.RequestHost}
		streamSetting.HttpSettings = h2Setting
	case "kcp":
		streamSetting.Network = "kcp"
		kcpSetting := &KcpSetting{}
		kcpSetting.Seed = s.Path
		kcpSetting.Mtu = 1350
		kcpSetting.Header.Type = s.HeaderType
		streamSetting.KcpSettings = kcpSetting
	case "quic":
		streamSetting.Network = "quic"
		quicSetting := &QuicSetting{}
		quicSetting.Security = s.HeaderType
		quicSetting.Key = s.Path
		quicSetting.Header.Type = s.HeaderType
		streamSetting.QuicSettings = quicSetting
	case "grpc":
		streamSetting.Network = "grpc"
		grpcSetting := &GrpcSetting{}
		grpcSetting.ServiceName = s.Path
		streamSetting.GrpcSettings = grpcSetting
	case "tcp":
		streamSetting.Network = "tcp"
	case "domainsocket":
		streamSetting.Network = "domainsocket"
		domainSocketSetting := &DomainSocketSetting{}
		domainSocketSetting.Path = s.Path
		streamSetting.DsSettings = domainSocketSetting
	default:
		streamSetting.Network = "tcp"
	}

	// security: "none" | "tls" | "reality" | "uTls"
	switch s.StreamSecurity {
	case "utls":
		// uTLS, https://www.v2fly.org/v5/config/stream.html#certificateobject
		// 您可以在以下传输方式中使用 uTLS: TCP,WebSocket
		streamSetting.Security = "utls"
		// todo utls
	case "tls":
		streamSetting.Security = "tls"
		tlsSetting := &TlsSetting{}
		tlsSetting.AllowInsecure = s.AllowInsecure == "1"
		tlsSetting.ServerName = s.Sni
		tlsSetting.Fingerprint = s.Fingerprint
		streamSetting.TlsSettings = tlsSetting
	case "reality":
		streamSetting.Security = "reality"
		realitySetting := &RealitySetting{}
		realitySetting.PublicKey = s.PublicKey
		realitySetting.ShortId = s.ShortId
		realitySetting.SpiderX = s.SpiderX
		realitySetting.ServerName = s.Sni
		streamSetting.RealitySettings = realitySetting
	}

	return streamSetting
}
