package main

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"log/slog"
	"net/http"
	"strings"
)

type JsonResp struct {
	Code int    `json:"code"`
	Msg  string `json:"msg"`
	Data any    `json:"data"`
}

type ApiInterface interface {
	OutRight(c *gin.Context, data interface{})
	OutError(c *gin.Context, errno int, msg ...string)
}

type ApiBase struct {
	ApiInterface
}

func (api *ApiBase) OutRight(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, &JsonResp{
		Code: 0,
		Msg:  "",
		Data: data,
	})
}

func (api *ApiBase) OutError(c *gin.Context, errno int, msg ...string) {
	msgStr := ""
	if len(msg) > 0 {
		msgStr = strings.Join(msg, ",")
	}
	c.JSON(http.StatusOK, JsonResp{
		Code: errno,
		Msg:  msgStr,
		Data: struct{}{},
	})
}

type ApiHandler struct {
	ApiBase
}

func NewApiHandler() *ApiHandler {
	s := new(ApiHandler)
	return s
}

// GetConfig get config
func (s *ApiHandler) GetConfig(c *gin.Context) {
	var _sql = fmt.Sprintf("select id,key,val from config")
	query, err := db.Query(_sql)
	if err != nil {
		slog.Error("Error:", err)
		s.OutError(c, 1, err.Error())
		return
	}
	list := make([]*ConfigInfo, 0)
	for query.Next() {
		var item = new(ConfigInfo)
		err = query.Scan(&item.Id, &item.Key, &item.Val)
		if err != nil {
			fmt.Println("Error:", err)
		} else {
			list = append(list, item)
		}
	}
	s.OutRight(c, list)
	return
}

var serverItemFields = []string{
	`_id`, `key`, `sub_key`, `sub_remark`, `type`, `remark`, `speed`, `url`, `json`, `address`,
	`port`, `id`, `alterId`, `security`, `network`, `headerType`, `requestHost`, `path`, `streamSecurity`, `allowInsecure`,
	`flow`, `sni`, `alpn`, `fingerprint`, `publicKey`, `shortId`, `spiderX`,
}
var serverItemPlaceholder = strings.Join(serverItemFields, ",")

// GetServerList get server list
func (s *ApiHandler) GetServerList(c *gin.Context) {
	mode := c.DefaultQuery("mode", "all") // all|vmess|vless|trojan|ss|ssr
	var _sql string
	switch mode {
	case "subscribe":
		_sql = fmt.Sprintf("select %s from server_item where sub_remark='' order by id asc", serverItemPlaceholder)
	case "normal":
		_sql = fmt.Sprintf("select %s from server_item where sub_remark='' order by id asc", serverItemPlaceholder)
	default:
		_sql = fmt.Sprintf("select %s from server_item order by id asc", serverItemPlaceholder)
	}
	query, err := db.Query(_sql)
	if err != nil {
		slog.Error("Error:", err)
		s.OutError(c, 1, err.Error())
		return
	}
	list := make([]*ServerItem, 0)
	for query.Next() {
		var item = new(ServerItem)
		err = query.Scan(
			&item.Id, &item.Key, &item.SubKey, &item.SubRemark, &item.Type, &item.Remark, &item.Speed, &item.Url, &item.Json, &item.Address,
			&item.Port, &item.MixId, &item.AlterId, &item.Security, &item.Network, &item.HeaderType, &item.RequestHost, &item.Path, &item.StreamSecurity, &item.AllowInsecure,
			&item.Flow, &item.Sni, &item.Alpn, &item.Fingerprint, &item.PublicKey, &item.ShortId, &item.SpiderX,
		)
		if err != nil {
			fmt.Println("Error:", err)
		} else {
			list = append(list, item)
		}
	}
	s.OutRight(c, list)
}

// GetServerStat get server stat
func (s *ApiHandler) GetServerStat(c *gin.Context) {

}

// Import import server
func (s *ApiHandler) Import(c *gin.Context) {

}
