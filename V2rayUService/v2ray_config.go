package main

type V2rayConfig struct {
	Log       V2rayLog     `json:"log"`
	Api       V2rayApi     `json:"api"`
	Policy    V2rayPolicy  `json:"policy"`
	Inbounds  []Inbound    `json:"inbounds"`
	Outbounds []Outbound   `json:"outbounds"`
	Dns       V2rayDNS     `json:"dns"`
	Routing   V2rayRouting `json:"routing"`
}

type V2rayLog struct {
	Access   string `json:"access"`
	Error    string `json:"error"`
	Loglevel string `json:"loglevel"`
	DnsLog   bool   `json:"dnsLog"`
}

type V2rayApi struct {
	Tag      string   `json:"tag"`
	Services []string `json:"services"`
}

type V2rayDNS struct {
	Hosts   map[string]string `json:"hosts"`
	Servers []any             `json:"servers"`
}

type V2rayDnsServer struct {
	Address   string   `json:"address"`
	Domains   []string `json:"domains"`
	ExpectIPs []string `json:"expectIPs"`
}

type V2rayRouting struct {
	DomainStrategy string             `json:"domainStrategy"`
	Rules          []V2rayRoutingRule `json:"rules"`
}

type V2rayRoutingRule struct {
	Type        string   `json:"type"`
	InboundTag  []string `json:"inboundTag"`
	OutboundTag string   `json:"outboundTag"`
	Port        string   `json:"port,omitempty"`
}

type V2rayPolicy struct {
	System struct {
		StatsOutboundUplink   bool `json:"statsOutboundUplink"`
		StatsOutboundDownlink bool `json:"statsOutboundDownlink"`
	} `json:"system"`
}

type FakeDNS struct {
	IpPool   string `json:"ipPool"`
	PoolSize int    `json:"poolSize"`
}

type Inbound struct {
	Listen   string `json:"listen"`
	Port     int    `json:"port"`
	Protocol string `json:"protocol"`
	Settings struct {
	} `json:"settings"`
	StreamSettings StreamSetting `json:"tag"`
	Sniffing       struct {
		Enabled      bool     `json:"enabled"`
		DestOverride []string `json:"destOverride"`
	} `json:"sniffing"`
	Allocate struct {
		Strategy    string `json:"strategy"`
		Refresh     int    `json:"refresh"`
		Concurrency int    `json:"concurrency"`
	} `json:"allocate"`
}

type Outbound struct {
	Protocol string `json:"protocol"` // 出站协议
	Tag      string `json:"tag"`      // 当其不为空时，其值必须在所有 tag 中 唯一。
	Settings any    `json:"settings"` // 出站协议配置
}

type OutboundDNS struct {
	Network    string `json:"network"`
	Address    string `json:"address"`
	Port       int    `json:"port"`
	NonIPQuery string `json:"nonIPQuery"`
}

type OutboundFreedom struct {
	DomainStrategy string `json:"domainStrategy"`
	Redirect       string `json:"redirect"`
	UserLevel      int    `json:"userLevel"`
	Fragment       struct {
		Packets  string `json:"packets"`
		Length   string `json:"length"`
		Interval string `json:"interval"`
	} `json:"fragment"`
}

type OutboundTrojan struct {
	Servers []OutboundTrojanItem `json:"servers"`
}

type OutboundTrojanItem struct {
	Address  string `json:"address"`         // 服务端地址，支持 IPv4、IPv6 和域名。必填。
	Port     int    `json:"port"`            // 服务端端口，通常与服务端监听的端口相同。
	Password string `json:"password"`        // 密码. 必填，任意字符串。
	Email    string `json:"email,omitempty"` // 邮件地址，可选，用于标识用户
	Level    int    `json:"level,omitempty"` // 用户等级，可选，默认值为 0。
}

type OutboundVMess struct {
	Vnext []VMessNext `json:"vnext"`
}
type VMessNext struct {
	Address string      `json:"address"`
	Port    int         `json:"port"`
	Users   []VMessUser `json:"users"`
}

type VMessUser struct {
	Id       string `json:"id"`              // Vmess 的用户 ID，可以是任意小于 30 字节的字符串, 也可以是一个合法的 UUID.
	Security string `json:"security"`        // 推荐使用"auto"加密方式，security: "aes-128-gcm" | "chacha20-poly1305" | "auto" | "none" | "zero"
	Level    int    `json:"level,omitempty"` // 用户等级，可选，默认值为 0。
}

type OutboundVLess struct {
	Vnext []VLessNext `json:"vnext"`
}

type VLessNext struct {
	Address string      `json:"address"` // 服务端地址，指向服务端，支持域名、IPv4、IPv6。
	Port    int         `json:"port"`    // 服务端端口，通常与服务端监听的端口相同。
	Users   []VLessUser `json:"users"`   // 数组, 一组服务端认可的用户列表, 其中每一项是一个用户配置
}

type VLessUser struct {
	Id         string `json:"id"`              // VLess 的用户 ID，
	Encryption string `json:"encryption"`      // encryption: "none"
	Flow       string `json:"flow"`            // 流控模式，用于选择 XTLS 的算法: xtls-rprx-vision,xtls-rprx-vision-udp443
	Level      int    `json:"level,omitempty"` // 用户等级，可选，默认值为 0。
}

type OutboundShadowsock struct {
	Servers []ShadowsockItem `json:"servers"`
}

type ShadowsockItem struct {
	Address string `json:"address"` // Shadowsocks 服务端地址，支持 IPv4、IPv6 和域名。必填。
	Port    int    `json:"port"`    // Shadowsocks 服务端端口。必填。
	// 推荐的加密方式： 2022-blake3-aes-128-gcm,2022-blake3-aes-256-gcm,2022-blake3-chacha20-poly1305
	// 其他加密方式: none 或 plain,aes-256-gcm,aes-128-gcm,chacha20-poly1305 或称 chacha20-ietf-poly1305,xchacha20-poly1305 或称 xchacha20-ietf-poly1305
	Method     string `json:"method"`          // 必填。
	Password   string `json:"password"`        // 必填。
	Uot        bool   `json:"uot"`             // 必填。启用udp over tcp。
	UoTVersion int    `json:"UoTVersion"`      // UDP over TCP 的实现版本。当前可选值：1, 2
	Email      string `json:"email,omitempty"` // 邮件地址，可选，用于标识用户
	Level      int    `json:"level,omitempty"` // 用户等级，可选，默认值为 0。
}

type StreamSetting struct {
	Network      string              `json:"network"`
	Security     string              `json:"security"`
	TlsSettings  TlsSetting          `json:"tlsSettings,omitempty"`
	TcpSettings  TcpSetting          `json:"tcpSettings,omitempty"`
	KcpSettings  KcpSetting          `json:"kcpSettings,omitempty"`
	WsSettings   WsSetting           `json:"wsSettings,omitempty"`
	HttpSettings HttpSetting         `json:"httpSettings,omitempty"`
	QuicSettings QuicSetting         `json:"quicSettings,omitempty"`
	DsSettings   DomainSocketSetting `json:"dsSettings,omitempty"`
	GrpcSettings GrpcSetting         `json:"grpcSettings,omitempty"`
	Sockopt      struct {
		Mark                 int    `json:"mark"`
		TcpFastOpen          bool   `json:"tcpFastOpen"`
		Tproxy               string `json:"tproxy"`
		DomainStrategy       string `json:"domainStrategy"`
		DialerProxy          string `json:"dialerProxy"`
		AcceptProxyProtocol  bool   `json:"acceptProxyProtocol"`
		TcpKeepAliveInterval int    `json:"tcpKeepAliveInterval"`
	} `json:"sockopt"`
}

type TlsSetting struct {
	ServerName                       string        `json:"serverName"`       // 指定服务器端证书的域名，在连接由 IP 建立时有用。
	RejectUnknownSni                 bool          `json:"rejectUnknownSni"` // 当值为 true 时，服务端接收到的 SNI 与证书域名不匹配即拒绝 TLS 握手，默认为 false。
	AllowInsecure                    bool          `json:"allowInsecure"`    // 默认值为 false。 (出于安全性考虑，这个选项不应该在实际场景中选择 true，否则可能遭受中间人攻击。 )
	Alpn                             []string      `json:"alpn"`             // 一个字符串数组，指定了 TLS 握手时指定的 ALPN 数值。默认值为 ["h2", "http/1.1"]。
	MinVersion                       string        `json:"minVersion"`
	MaxVersion                       string        `json:"maxVersion"`
	CipherSuites                     string        `json:"cipherSuites"`
	Certificates                     []interface{} `json:"certificates"`
	DisableSystemRoot                bool          `json:"disableSystemRoot"`
	EnableSessionResumption          bool          `json:"enableSessionResumption"`
	Fingerprint                      string        `json:"fingerprint"` // 当其值为空时，表示不启用此功能
	PinnedPeerCertificateChainSha256 []string      `json:"pinnedPeerCertificateChainSha256"`
}

type TcpSetting struct {
	AcceptProxyProtocol bool `json:"acceptProxyProtocol"`
	Header              struct {
		Type string `json:"type"`
	} `json:"header"`
}

type KcpSetting struct {
	Mtu              int    `json:"mtu"`
	Tti              int    `json:"tti"`
	UplinkCapacity   int    `json:"uplinkCapacity"`
	DownlinkCapacity int    `json:"downlinkCapacity"`
	Congestion       bool   `json:"congestion"`
	ReadBufferSize   int    `json:"readBufferSize"`
	WriteBufferSize  int    `json:"writeBufferSize"`
	Header           Header `json:"header"`
	Seed             string `json:"seed"`
}

type Header struct {
	// 伪装类型，可选的值有：
	// "none"：默认值，不进行伪装，发送的数据是没有特征的数据包。
	// "srtp"：伪装成 SRTP 数据包，会被识别为视频通话数据（如 FaceTime）。
	// "utp"：伪装成 uTP 数据包，会被识别为 BT 下载数据。
	// "wechat-video"：伪装成微信视频通话的数据包。
	// "dtls"：伪装成 DTLS 1.2 数据包。
	// "wireguard"：伪装成 WireGuard 数据包。（并不是真正的 WireGuard 协议）
	Type string `json:"type"`
}

type WsSetting struct {
	Path    string `json:"path"`
	Headers struct {
		Host string `json:"Host"`
	} `json:"headers"`
}

// http2 setting

type HttpSetting struct {
	Host               []string `json:"host"` //客户端会随机从列表中选出一个域名进行通信，服务器会验证域名是否在列表中。
	Path               string   `json:"path"` // 默认值为 "/"。 HTTP 路径，由 / 开头, 客户端和服务器必须一致。
	ReadIdleTimeout    int      `json:"read_idle_timeout"`
	HealthCheckTimeout int      `json:"health_check_timeout"`
	Method             string   `json:"method"` // HTTP 方法。默认值为 "PUT"。
	Headers            struct { // 自定义 HTTP 头，一个键值对，每个键表示一个 HTTP 头名称，对应值为一个数组。
		Header []string `json:"Header"`
	} `json:"headers"`
}

type QuicSetting struct {
	Security string `json:"security"` // 默认值为不加密。 security: "none" | "aes-128-gcm" | "chacha20-poly1305"
	Key      string `json:"key"`      // 可以是任意字符串。当 security 不为 "none" 时有效。
	Header   Header `json:"header"`   // 头
}

type GrpcSetting struct {
	ServiceName         string `json:"serviceName"`          //一个字符串，指定服务名称，类似于 HTTP/2 中的 Path。 客户端会使用此名称进行通信，服务端会验证服务名称是否匹配。
	MultiMode           bool   `json:"multiMode"`            // true 启用 multiMode，默认值为： false。
	UserAgent           string `json:"user_agent,omitempty"` // 设置 gRPC 的用户代理，可能能防止某些 CDN 阻止 gRPC 流量。
	IdleTimeout         int    `json:"idle_timeout,omitempty"`
	HealthCheckTimeout  int    `json:"health_check_timeout,omitempty"`
	PermitWithoutStream bool   `json:"permit_without_stream,omitempty"`
	InitialWindowsSize  int    `json:"initial_windows_size,omitempty"`
}

type DomainSocketSetting struct {
	Path     string `json:"path"`     // 一个合法的文件路径。在运行 Xray 之前，这个文件必须不存在。
	Abstract bool   `json:"abstract"` // 是否为 abstract domain socket，默认值 false。
	Padding  bool   `json:"padding"`  // abstract domain socket 是否带 padding，默认值 false。
}

type RealitySetting struct {
	Show        bool   `json:"show"`        // 当值为 true 时，输出调试信息。
	ShortId     string `json:"shortId"`     // 服务端 shortIds 之一。0 到 f，长度为 2 的倍数，长度上限为 16。若服务端的 shordIDs 包含空值，客户端可为空。
	ServerName  string `json:"serverName"`  // 服务端 serverNames 之一。
	Fingerprint string `json:"fingerprint"` // 必填, 如空值，需填写 ·chrome·
	PublicKey   string `json:"publicKey"`   // 必填，服务端私钥对应的公钥。使用 ./xray x25519 -i "服务器私钥" 生成。
	SpiderX     string `json:"spiderX"`     // 爬虫初始路径与参数，建议每个客户端不同。
}
