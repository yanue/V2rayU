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
CREATE TABLE IF NOT EXISTS "config"
(
    "_id" INTEGER NOT NULL,
    "key" varchar not null default '',
    "val" varchar not null default '',
    PRIMARY KEY ("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "routing"
(
    "_id"            INTEGER NOT NULL,
    "remark"         varchar not null default '',
    "url"            varchar not null default '',
    "ruleSet"        varchar not null default '',
    "ruleNum"        integer not null default 0,
    "enabled"        integer not null default 0,
    "locked"         integer not null default 0,
    "customIcon"     varchar not null default '',
    "domainStrategy" varchar not null default '',
    "sort"           integer not null default 0,
    PRIMARY KEY ("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "server_item"
(
    "_id"            INTEGER        NOT NULL,
    "key"            varchar UNIQUE not null default '',
    "sub_key"        varchar        not null default '',
    "sub_remark"     varchar        not null default '',
    "type"           varchar        not null default '',
    "remark"         varchar        not null default '',
    "speed"          integer        not null default 0,
    "address"        varchar        not null default '',
    "url"            varchar        not null default '',
    "json"           varchar        not null default '',
    "port"           integer        not null default 0,
    "id"             varchar        not null default '',
    "alterId"        integer        not null default 0,
    "security"       varchar        not null default '',
    "network"        varchar        not null default '',
    "headerType"     varchar        not null default '',
    "requestHost"    varchar        not null default '',
    "path"           varchar        not null default '',
    "streamSecurity" varchar        not null default '',
    "allowInsecure"  varchar        not null default '',
    "flow"           varchar        not null default '',
    "sni"            varchar        not null default '',
    "alpn"           varchar        not null default '',
    "fingerprint"    varchar        not null default '',
    "publicKey"      varchar        not null default '',
    "shortId"        varchar        not null default '',
    "spiderX"        varchar        not null default '',
    UNIQUE ("sub_key", "address", "port")
        PRIMARY KEY ("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "server_stat"
(
    "_id"       INTEGER NOT NULL,
    "totalUp"   integer not null default 0,
    "totalDown" integer not null default 0,
    "todayUp"   integer not null default 0,
    "todayDown" integer not null default 0,
    "dateNow"   integer not null default 0,
    PRIMARY KEY ("_id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "sub_item"
(
    "_id"                  INTEGER NOT NULL,
    "key"                  varchar not null default '' UNIQUE,
    "sub_type"             varchar not null default '',
    "remark"               varchar not null default '',
    "url"                  varchar not null default '' UNIQUE,
    "enabled"              integer not null default 0,
    "sort"                 integer not null default 0,
    "auto_update_interval" integer not null default 0,
    "update_time"          INTEGER not null default 0,
    PRIMARY KEY ("_id" AUTOINCREMENT)
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
