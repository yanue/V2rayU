package main

type Trojan struct {
	ImportBase
}

func (s *Trojan) doImport(uri string, subKey string) (item ServerItem) {
	s.subKey = subKey
	s.decodeBaseUrl(uri)
	if s.err != nil {
		return
	}
	item.Address = s._uri.Host
	item.Port = ToInt(s._uri.Port())
	if s._uri.User != nil {
		item.MixId = s._uri.User.Username()
	}
	values := s._uri.Query()
	item.Type = "trojan"
	item.Network = "tcp"
	item.Sni = values.Get("sni")
	item.StreamSecurity = values.Get("security")
	item.Fingerprint = values.Get("fp")
	item.Flow = values.Get("flow")
	if item.StreamSecurity == "" {
		item.StreamSecurity = "tls"
	}
	if len(item.Fingerprint) == 0 {
		item.Fingerprint = "chrome"
	}
	item.Remark = s.remark // # 后面的内容
	item.Url = uri
	s.saveImport(item)
	return ServerItem{}
}
