package main

import (
	"database/sql"
	"fmt"
	_ "github.com/mattn/go-sqlite3"
	"log"
	"os/user"
)

var db *sql.DB

var initSql = `
CREATE TABLE IF NOT EXISTS "config" (
	"_id"	INTEGER,
	"key"	TEXT,
	"val"	TEXT,
	PRIMARY KEY("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "routing" (
	"_id"	INTEGER NOT NULL,
	"remark"	varchar,
	"url"	varchar,
	"ruleSet"	varchar,
	"ruleNum"	integer,
	"enabled"	integer,
	"locked"	integer,
	"customIcon"	varchar,
	"domainStrategy"	varchar,
	"sort"	integer,
	PRIMARY KEY("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "server_item" (
	"_id"	INTEGER,
	"key"	varchar UNIQUE,
	"sub_key"	varchar,
	"type"	varchar,
	"remark"	varchar,
	"speed" 	integer,
	"address"	varchar,
	"url"	text,
	"json"	text,
	"port"	integer,
	"id"	varchar,
	"alterId"	integer,
	"security"	varchar,
	"network"	varchar,
	"headerType"	varchar,
	"requestHost"	varchar,
	"path"	varchar,
	"streamSecurity"	varchar,
	"allowInsecure"	varchar,
	"flow"	varchar,
	"sni"	varchar,
	"alpn"	varchar,
	"fingerprint"	varchar,
	"publicKey"	varchar,
	"shortId"	varchar,
	"spiderX"	varchar,
	UNIQUE ("sub_key","address","port")
	PRIMARY KEY("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "server_stat" (
	"_id"	varchar NOT NULL,
	"totalUp"	integer,
	"totalDown"	integer,
	"todayUp"	integer,
	"todayDown"	integer,
	"dateNow"	integer,
	PRIMARY KEY("_id")
);
CREATE TABLE IF NOT EXISTS "sub_item" (
	"_id"	INTEGER,
	"key"	TEXT UNIQUE,
	"sub_type"	TEXT,
	"remark"	TEXT,
	"url"	TEXT UNIQUE,
	"enabled"	integer,
	"sort"	integer,
	"auto_update_interval"	integer,
	"update_time"	INTEGER,
	PRIMARY KEY("_id" AUTOINCREMENT)
);
-- default routing
INSERT INTO "routing" ("_id", "remark", "url", "ruleSet", "ruleNum", "enabled", "locked", "customIcon", "domainStrategy", "sort") VALUES ('1', '绕过大陆(Whitelist)', '', '[{"id":"5580264978215010713","outboundTag":"direct","domain":["domain:example-example.com","domain:example-example2.com"],"enabled":true},{"id":"5064543300651137083","outboundTag":"block","domain":["geosite:category-ads-all"],"enabled":true},{"id":"5232676580862334797","outboundTag":"direct","domain":["geosite:cn"],"enabled":true},{"id":"5048348083573612254","outboundTag":"direct","ip":["geoip:private","geoip:cn"],"enabled":true},{"id":"5384766660577926508","port":"0-65535","outboundTag":"proxy","enabled":true}]', '5', '1', '0', '', '', '1');
INSERT INTO "routing" ("_id", "remark", "url", "ruleSet", "ruleNum", "enabled", "locked", "customIcon", "domainStrategy", "sort") VALUES ('2', '黑名单(Blacklist)', '', '[{"id":"5226003415530607067","outboundTag":"direct","protocol":["bittorrent"],"enabled":true},{"id":"5313016716646935153","outboundTag":"block","domain":["geosite:category-ads-all"],"enabled":true},{"id":"5483964387337920337","outboundTag":"proxy","ip":["geoip:cloudflare","geoip:cloudfront","geoip:facebook","geoip:fastly","geoip:google","geoip:netflix","geoip:telegram","geoip:twitter"],"domain":["geosite:gfw","geosite:greatfire","geosite:tld-!cn"],"enabled":true},{"id":"4790120951982911403","port":"0-65535","outboundTag":"direct","enabled":true}]', '4', '1', '0', '', '', '2');
INSERT INTO "routing" ("_id", "remark", "url", "ruleSet", "ruleNum", "enabled", "locked", "customIcon", "domainStrategy", "sort") VALUES ('3', '全局(Global)', '', '[{"id":"5125070952045213718","port":"0-65535","outboundTag":"proxy","enabled":true}]', '1', '1', '0', '', '', '3');
INSERT INTO "routing" ("_id", "remark", "url", "ruleSet", "ruleNum", "enabled", "locked", "customIcon", "domainStrategy", "sort") VALUES ('4', 'locked', '', '[{"id":"4685028068716118787","outboundTag":"proxy","domain":["geosite:google"],"enabled":true},{"id":"4705737006595691425","outboundTag":"direct","domain":["domain:example-example.com","domain:example-example2.com"],"enabled":true},{"id":"5099766859122618357","outboundTag":"block","domain":["geosite:category-ads-all"],"enabled":true}]', '3', '1', '1', '', '', '0');
INSERT INTO "routing" ("_id", "remark", "url", "ruleSet", "ruleNum", "enabled", "locked", "customIcon", "domainStrategy", "sort") VALUES ('5', '全局(Global)', '', '[{"id":"5440390852335786669","port":"0-65535","outboundTag":"proxy","enabled":true}]', '1', '1', '0', '', '', '0');
`

func initDb() {
	var err error
	CurrentUser, err := user.Current()
	if err != nil {
		fmt.Println("Error:", err)
	}
	dbFile := CurrentUser.HomeDir + "/.V2rayU.db"
	db, err = sql.Open("sqlite3", dbFile)
	if err != nil {
		panic(err)
	}
	_, err = db.Exec(initSql)
	if err != nil {
		log.Println("init db error: ", err)
		return
	}
}
