package main

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// 初始-http.Client
func newHttpClient(proxyUrl string, timeout time.Duration) *http.Client {
	// 配置参数
	return &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			Proxy: func(request *http.Request) (*url.URL, error) {
				if len(proxyUrl) > 0 {
					if proxy, err := url.Parse(proxyUrl); err == nil {
						return proxy, nil
					}
				}
				return nil, nil
			},
			TLSHandshakeTimeout:   timeout,
			ResponseHeaderTimeout: timeout,
			ExpectContinueTimeout: timeout,
		},
	}
}

func ToInt(value interface{}) (i int) {
	switch v := value.(type) {
	case bool:
		i = 1
		if v {
			i = 0
		}
	case float32:
		i = int(v)
	case float64:
		i = int(v)
	case int:
		i = v
	case int8:
		i = int(v)
	case int16:
		i = int(v)
	case int32:
		i = int(v)
	case int64:
		i = int(v)
	case uint:
		i = int(v)
	case uint8:
		i = int(uint(v))
	case uint16:
		i = int(uint(v))
	case uint32:
		i = int(uint(v))
	case uint64:
		i = int(uint(v))
	case string:
		i, _ = strconv.Atoi(v)
	case []byte:
		i = int(ByteToInt64(v))
	default:
		str := fmt.Sprintf("%d", v)
		i, _ = strconv.Atoi(str)
	}
	return i
}

// ByteToInt64 converts an int64 in bytes to int64 with BigEndian
func ByteToInt64(data []byte) int64 {
	var value int64
	buf := bytes.NewReader(data)
	_ = binary.Read(buf, binary.BigEndian, &value)
	return value
}

func ToJson(input any) string {
	js, _ := json.MarshalIndent(input, "", " ")
	return string(js)
}

// 尝试解析base64, 如果解析失败, 则返回原字符串
func tryDecodeBase64(input string) string {
	input = strings.Trim(input, " ")
	// try URLEncoding
	decodeStr, err := base64.URLEncoding.DecodeString(input)
	if err == nil {
		return string(decodeStr)
	}
	// try RawURLEncoding
	decodeStr, err = base64.RawURLEncoding.DecodeString(input)
	if err == nil {
		return string(decodeStr)
	}
	// 返回原始字符串
	return input
}
