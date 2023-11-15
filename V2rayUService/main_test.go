package main

import (
	"fmt"
	"strings"
	"testing"
)

func init() {
	initDb()
}

func TestCases(t *testing.T) {
	testCases := []string{
		"trojan://what.ever@www.twitter.com:443?allowInsecure=1&allowInsecureHostname=1&allowInsecureCertificate=1&sessionTicket=0&tfo=1#some-trojan",
		"vmess://eyJ2IjogIjIiLCAicHMiOiAiXHU2NmY0XHU2NWIwXHU0ZThlOjEwLTE3IDE2OjAwIC1ieSBCdUxpbmsueHl6LSBcdTRlZTVcdTRlMGJcdTgyODJcdTcwYjlcdTRlMGRcdThiYTFcdTZkNDFcdTkxY2YiLCAiYWRkIjogIlx1NGY3Zlx1NzUyOFx1NTI0ZFx1OGJiMFx1NWY5N1x1NjZmNFx1NjViMFx1OGJhMlx1OTYwNSIsICJwb3J0IjogIjAiLCAiaWQiOiAiNmEzYmNjMDgtOWM3Ny00YzAyLTg0NGItNGE2OTRjNGYyZmVhIiwgImFpZCI6ICIwIiwgIm5ldCI6ICJ0Y3AiLCAidHlwZSI6ICJub25lIiwgImhvc3QiOiAiIiwgInBhdGgiOiAiIiwgInRscyI6ICIifQ==\nvmess://eyJhZGQiOiAiNzQuNDguOTguMjQ5IiwgImFpZCI6IDAsICJob3N0IjogIiIsICJpZCI6ICJmMTNmMmEwYS1mYjQ5LTQxMzktOGZjYy02MThjZGFmMjkzOGIiLCAibmV0IjogIndzIiwgInBhdGgiOiAiL3F1YW5zdHJpbmc_ZWQ9MjA0OCIsICJwb3J0IjogODA4MCwgInBzIjogImdpdGh1Yi5jb20vZnJlZWZxIC0gXHU1MmEwXHU2MmZmXHU1OTI3VEVMVVMgMSIsICJ0bHMiOiAiIiwgInR5cGUiOiAiYXV0byIsICJzZWN1cml0eSI6ICJhdXRvIiwgInNraXAtY2VydC12ZXJpZnkiOiB0cnVlLCAic25pIjogIiJ9\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRcdTUyYTBcdTUyMjlcdTc5OGZcdTVjM2NcdTRlOWFcdTVkZGVcdTU3MjNcdTRmNTVcdTU4NWVQRUcgVEVDSCAyIiwgImFkZCI6ICIxNDIuNC4xMTAuMTQyIiwgInBvcnQiOiAzMDAwMCwgImlkIjogIjY4ZDIzOGNlLTNjYTEtNDZkYy1iODMzLWEwOTE2YzgyOWFkMyIsICJhaWQiOiA2NCwgInNjeSI6ICJhdXRvIiwgIm5ldCI6ICJ3cyIsICJob3N0IjogInd3dy4yODI1MTY1OC54eXoiLCAicGF0aCI6ICIvcGF0aC8xNjk3Mzc2NzgyODc5IiwgInRscyI6ICJ0bHMifQ==\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRcdTUyYTBcdTUyMjlcdTc5OGZcdTVjM2NcdTRlOWFcdTVkZGVcdTZkMWJcdTY3NDlcdTc3ZjZQZXRhRXhwcmVzcyAzIiwgImFkZCI6ICIxOTguMi4yMDcuMTE4IiwgInBvcnQiOiA0NDMsICJpZCI6ICI0MTgwNDhhZi1hMjkzLTRiOTktOWIwYy05OGNhMzU4MGRkMjQiLCAiYWlkIjogNjQsICJzY3kiOiAiYXV0byIsICJuZXQiOiAid3MiLCAiaG9zdCI6ICJ3d3cuNjM3NjMwNzkueHl6IiwgInBhdGgiOiAiL3BhdGgvMTY5NzM3Njc4Mjg3OSIsICJ0bHMiOiAidGxzIn0=\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRcdTUyYTBcdTUyMjlcdTc5OGZcdTVjM2NcdTRlOWFcdTVkZGVcdTU3MjNcdTRmNTVcdTU4NWVNVUxUQUNPTVx1NjczYVx1NjIzZiA0IiwgImFkZCI6ICI0NS4xOTkuMTM4LjE4NiIsICJwb3J0IjogMzAwMDAsICJpZCI6ICI0ZWMwYWU2Mi1kZTA5LTQwMjktOTA0YS0wMzEzZDQ2MjhlY2YiLCAiYWlkIjogNjQsICJzY3kiOiAiYXV0byIsICJuZXQiOiAid3MiLCAiaG9zdCI6ICJ3d3cuMTkyMjkzNjIueHl6IiwgInBhdGgiOiAiL3BhdGgvMTY5NzM3Njc4Mjg3OSIsICJ0bHMiOiAidGxzIn0=\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRcdTUyYTBcdTUyMjlcdTc5OGZcdTVjM2NcdTRlOWFcdTVkZGVcdTU3MjNcdTRmNTVcdTU4NWVNVUxUQUNPTVx1NjczYVx1NjIzZiA1IiwgImFkZCI6ICI0NS4xOTkuMTM4LjIwNSIsICJwb3J0IjogMzAwMDAsICJpZCI6ICIyMGIzMDkxNi1lMjAzLTQxMmUtOGVjMC05MDBmM2FjZDUxMjgiLCAiYWlkIjogNjQsICJzY3kiOiAiYXV0byIsICJuZXQiOiAid3MiLCAiaG9zdCI6ICJ3d3cuNjk3MDgyNzIueHl6IiwgInBhdGgiOiAiL3BhdGgvMTY5NzI4ODcyMjI2NiIsICJ0bHMiOiAidGxzIn0=\nvmess://eyJhZGQiOiAiMTA0LjE4LjIwMi4yMzIiLCAiYWlkIjogMCwgImhvc3QiOiAiZGUxdm0uY2RuLTAzLmxpdmUiLCAiaWQiOiAiNmJmMWIzNDItMmJmMC00NjA4LWIyODgtOGVlNTE1ZTJkNTk0IiwgIm5ldCI6ICJ3cyIsICJwYXRoIjogIi9AaG9wZXYycmF5XHUwNjBjQGhvcGV2MnJheSIsICJwb3J0IjogODAsICJwcyI6ICJnaXRodWIuY29tL2ZyZWVmcSAtIFx1N2Y4ZVx1NTZmZENsb3VkRmxhcmVcdTUxNmNcdTUzZjhDRE5cdTgyODJcdTcwYjkgNiIsICJ0bHMiOiAiIiwgInR5cGUiOiAiYXV0byIsICJzZWN1cml0eSI6ICJhdXRvIiwgInNraXAtY2VydC12ZXJpZnkiOiB0cnVlLCAic25pIjogIiJ9\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRDbG91ZGlubm92YXRpb25cdTY1NzBcdTYzNmVcdTRlMmRcdTVmYzMgNyIsICJhZGQiOiAiMTU0Ljg1LjEuMjQ0IiwgInBvcnQiOiAzMDAwMCwgImlkIjogIjFkNDc0ZjBiLWU3OGQtNGFmOS1iYzRhLWE0Njc0NjdiYzdhNyIsICJhaWQiOiA2NCwgInNjeSI6ICJhdXRvIiwgIm5ldCI6ICJ3cyIsICJob3N0IjogInd3dy4yODExNTM2MS54eXoiLCAicGF0aCI6ICIvcGF0aC8xNjk2OTQ0ODA2OTYxIiwgInRscyI6ICJ0bHMifQ==\nvmess://eyJhZGQiOiAibW0yLnNoYWJpamljaGFuZy5jb20iLCAidiI6IDIsICJwcyI6ICJnaXRodWIuY29tL2ZyZWVmcSAtIFx1N2Y4ZVx1NTZmZENsb3VkRmxhcmVcdTgyODJcdTcwYjkgOCIsICJwb3J0IjogIjgwIiwgImlkIjogIjEwZWEzYjJhLWI2MTUtNDVmMS1iMWI3LWM2MmJhZmU4YzgwYyIsICJhaWQiOiAiMCIsICJzY3kiOiAiYXV0byIsICJuZXQiOiAid3MiLCAidHlwZSI6ICIiLCAiaG9zdCI6ICJtbTIuc2hhYmlqaWNoYW5nLmNvbSIsICJ0bHMiOiAiIiwgInBhdGgiOiAiLyJ9\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTUzNTdcdTk3NWUgIDkiLCAiYWRkIjogIjE1Ni4yMjUuNjcuMTA0IiwgInBvcnQiOiAiMzAwMDAiLCAiaWQiOiAiMjlhNWQ0OGUtMjRmMS00OGZkLWE1ZTEtOWE0NmNiMzEwMzJmIiwgImFpZCI6ICI2NCIsICJzY3kiOiAiYXV0byIsICJuZXQiOiAid3MiLCAidHlwZSI6ICJub25lIiwgImhvc3QiOiAid3d3LjQxNzU4MTEyLnh5eiIsICJwYXRoIjogIi9wYXRoLzE2OTY5NDQ4MDY5NjEiLCAidGxzIjogInRscyIsICJzbmkiOiAiIiwgImFscG4iOiAiIn0=\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTVlN2ZcdTRlMWNcdTc3MDFcdTc5ZmJcdTUyYTggMTAiLCAiYWRkIjogIjE4My4yMzguMjAyLjE3MyIsICJwb3J0IjogIjUxOTA0IiwgImlkIjogIjQxODA0OGFmLWEyOTMtNGI5OS05YjBjLTk4Y2EzNTgwZGQyNCIsICJhaWQiOiAiNjQiLCAic2N5IjogImF1dG8iLCAibmV0IjogInRjcCIsICJ0eXBlIjogIm5vbmUiLCAiaG9zdCI6ICIiLCAicGF0aCI6ICIvIiwgInRscyI6ICIiLCAic25pIjogIiIsICJhbHBuIjogIiJ9\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRDbG91ZEZsYXJlXHU4MjgyXHU3MGI5IDExIiwgImFkZCI6ICJqZDIuc2hhYmlqaWNoYW5nLmNvbSIsICJwb3J0IjogIjgwIiwgImlkIjogIjU2Mjc4YTFhLWM3Y2MtNDU5Zi1iMDBjLTMwMzdlNGY5OTU5MCIsICJhaWQiOiAiMCIsICJzY3kiOiAiYXV0byIsICJuZXQiOiAid3MiLCAidHlwZSI6ICJub25lIiwgImhvc3QiOiAiamQyLnNoYWJpamljaGFuZy5jb20iLCAicGF0aCI6ICIvIiwgInRscyI6ICIiLCAic25pIjogIiIsICJhbHBuIjogIiJ9\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRDbG91ZEZsYXJlXHU1MTZjXHU1M2Y4Q0ROXHU4MjgyXHU3MGI5IDEyIiwgImFkZCI6ICJjYzMuc2hhYmlqaWNoYW5nLmNvbSIsICJwb3J0IjogODAsICJpZCI6ICJjNDU4Njk1ZC02OTA4LTQ1YzMtOTUxMi1lMGM0NjQxODQ1NGMiLCAiYWlkIjogMCwgInNjeSI6ICJhdXRvIiwgIm5ldCI6ICJ3cyIsICJob3N0IjogImNjMy5zaGFiaWppY2hhbmcuY29tIiwgInBhdGgiOiAiLyIsICJ0bHMiOiAiIn0=\nss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTozNTI1NTg4ZWUxNGVhOTI0@gzcm01.celerlink.one:41040#github.com/freefq%20-%20%E5%B9%BF%E4%B8%9C%E7%9C%81%E6%B7%B1%E5%9C%B3%E5%B8%82%E7%A7%BB%E5%8A%A8%2013\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRcdTUzNGVcdTc2ZGJcdTk4N2ZcdTVkZGVcdTg5N2ZcdTk2YzVcdTU2ZmVcdTVlMDJcdTRlOWFcdTlhNmNcdTkwMGEoQW1hem9uKVx1NTE2Y1x1NTNmOFx1NjU3MFx1NjM2ZVx1NGUyZFx1NWZjMyAxNCIsICJhZGQiOiAia3ItY2RuLTYyNzM4MTkuc3Rhcm5ldGNuLnRvcCIsICJwb3J0IjogIjMxMjM1IiwgImlkIjogIjhlNzNmNTBhLTM1Y2QtNDIzNS05YzE4LWEzZTA2MWU3YmM5ZiIsICJhaWQiOiAiMCIsICJuZXQiOiAid3MiLCAidHlwZSI6ICJub25lIiwgImhvc3QiOiAianhob2lzbGR5NzE4OTIyLnN0YXJuZXRjbi50b3AiLCAicGF0aCI6ICIvMzE1ZDgyNTg5M2ZjMzRhY2EwMjMxYWI5NjcxNTc5ODYiLCAidGxzIjogIiJ9\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRDbG91ZEZsYXJlXHU4MjgyXHU3MGI5IDE1IiwgImFkZCI6ICJ5ZDEuOTkyNjg4Lnh5eiIsICJwb3J0IjogMjA1MiwgImlkIjogIjY5NjM5MjBhLThiYjMtNGY4Ny1iMjMxLTU2Y2NiOWY5YjNhNyIsICJhaWQiOiAwLCAic2N5IjogImF1dG8iLCAibmV0IjogIndzIiwgImhvc3QiOiAidmNldTMudnBuNjYuZXUub3JnIiwgInBhdGgiOiAiLyIsICJ0bHMiOiAiIn0=\nvmess://eyJhZGQiOiAibnMxLnYyLXZpcC5mdW4iLCAiYWlkIjogMCwgImhvc3QiOiAic3Nyc3ViLnYwMDUuc3Nyc3ViLmNvbSIsICJpZCI6ICJkM2Y4MzBhMi0yMDVhLTRiYmEtYTdjYS01ZTg3ODk5YWMwNGQiLCAibmV0IjogIndzIiwgInBhdGgiOiAiL2FwaS92My9kb3dubG9hZC5nZXRGaWxlIiwgInBvcnQiOiA4MDgwLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRDbG91ZEZsYXJlXHU4MjgyXHU3MGI5IDE2IiwgInRscyI6ICIiLCAidHlwZSI6ICJhdXRvIiwgInNlY3VyaXR5IjogImF1dG8iLCAic2tpcC1jZXJ0LXZlcmlmeSI6IHRydWUsICJzbmkiOiAiIn0=\nvmess://eyJ2IjogIjIiLCAicHMiOiAiZ2l0aHViLmNvbS9mcmVlZnEgLSBcdTdmOGVcdTU2ZmRDbG91ZEZsYXJlXHU4MjgyXHU3MGI5IDE3IiwgImFkZCI6ICJsdDEuOTkyNjg4Lnh5eiIsICJwb3J0IjogMjA1MiwgImlkIjogImZhNWZjNzRmLTBmMGItNDIyMS04MmJhLWRjN2NkMjRlMjRlNSIsICJhaWQiOiAwLCAic2N5IjogImF1dG8iLCAibmV0IjogIndzIiwgImhvc3QiOiAidmN1czIudnBuNjYuZXUub3JnIiwgInBhdGgiOiAiLyIsICJ0bHMiOiAiIn0=\n",
		"ssr://server:port:protocol:method:obfs:password_base64/?params_base64",
		"ssr://d3d3LnR3aXR0ZXIuY29tOjgwOmF1dGhfc2hhMV92NDpjaGFjaGEyMDpwbGFpbjpZbkpsWVd0M1lXeHMvP29iZnNwYXJhbT0mcmVtYXJrcz02TC1INXB5ZjVwZTI2WmUwNzd5YU1qQXlNQzB3TnkweE9DQXhNam8xTlRveU1RJmdyb3VwPVEzUkRiRzkxWkNCVFUxSQ",
		"vmess://eyJhZGQiOiJtb3RoZXIuZnVja2VyIiwiYWlkIjowLCJpZCI6IjFmYzI0NzVmLThmNDMtM2FlYi05MzUyLTU2MTFhZjg1NmQyOSIsIm5ldCI6InRjcCIsInBvcnQiOjEwMDg2LCJwcyI6Iui/h+acn+aXtumXtO+8mjIwMjAtMDYtMjMiLCJ0bHMiOiJub25lIiwidHlwZSI6Im5vbmUiLCJ2IjoyfQ==",
		"vmess://eyJhZGQiOiAiNzQuNDguOTguMjQ5IiwgImFpZCI6IDAsICJob3N0IjogIiIsICJpZCI6ICJmMTNmMmEwYS1mYjQ5LTQxMzktOGZjYy02MThjZGFmMjkzOGIiLCAibmV0IjogIndzIiwgInBhdGgiOiAiL3F1YW5zdHJpbmc_ZWQ9MjA0OCIsICJwb3J0IjogODA4MCwgInBzIjogImdpdGh1Yi5jb20vZnJlZWZxIC0gXHU1MmEwXHU2MmZmXHU1OTI3VEVMVVMgMSIsICJ0bHMiOiAiIiwgInR5cGUiOiAiYXV0byIsICJzZWN1cml0eSI6ICJhdXRvIiwgInNraXAtY2VydC12ZXJpZnkiOiB0cnVlLCAic25pIjogIiJ9",
		"vmess://99c80931-f3f1-4f84-bffd-6eed6030f53d@qv2ray.net:31415?encryption=none#VMessTCPNaked",
		"vmess://f08a563a-674d-4ffb-9f02-89d28aec96c9@qv2ray.net:9265#VMessTCPAuto",
		"vmess://5dc94f3a-ecf0-42d8-ae27-722a68a6456c@qv2ray.net:35897?encryption=aes-128-gcm#VMessTCPAES",
		"vmess://136ca332-f855-4b53-a7cc-d9b8bff1a8d7@qv2ray.net:9323?encryption=none&security=tls#VMessTCPTLSNaked",
		"vmess://be5459d9-2dc8-4f47-bf4d-8b479fc4069d@qv2ray.net:8462?security=tls#VMessTCPTLS",
		"vmess://c7199cd9-964b-4321-9d33-842b6fcec068@qv2ray.net:64338?encryption=none&security=tls&sni=fastgit.org#VMessTCPTLSSNI",
		"vmess://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:6939?type=ws&security=tls&host=qv2ray.net&path=%2Fsomewhere#VMessWebSocketTLS",
		"vless://b0dd64e4-0fbd-4038-9139-d1f32a68a0dc@qv2ray.net:3279?security=xtls&flow=rprx-xtls-splice#VLESSTCPXTLSSplice",
		"vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:50288?type=kcp&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeed",
		"vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:41971?type=kcp&headerType=wireguard&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeedWG",
	}
	for _, str := range testCases {
		fmt.Println("str", str)
		for _, uri := range strings.Split(str, "\n") {
			fmt.Println("uri", uri)
			serverImport.doImport(uri, "")
		}
	}
}

func TestClash(t *testing.T) {
	var clashTest1 = `
proxies:
- name: test-yaml1
  password: ba935023-8f89-482d-9371-646b67f90563
  port: 16946
  server: cxoxyis.lqftkz.xyz
  skip-cert-verify: true
  sni: v1-dy.ixigua.com
  type: trojan
  udp: true
- {"type":"ss","name":"v2rayse_test_1","server":"198.57.27.218","port":5004,"cipher":"aes-256-gcm","password":"g5MeD6Ft3CWlJId"}
- {"type":"ssr","name":"v2rayse_test_3","server":"20.239.49.44","port":59814,"protocol":"origin","cipher":"dummy","obfs":"plain","password":"3df57276-03ef-45cf-bdd4-4edb6dfaa0ef"}
- {"type":"vmess","name":"v2rayse_test_2","ws-opts":{"path":"/"},"server":"154.23.190.162","port":443,"uuid":"b9984674-f771-4e67-a198-","alterId":"0","cipher":"auto","network":"ws"}
- {"type":"vless","name":"test","server":"1.2.3.4","port":7777,"uuid":"abc-def-ghi-fge-zsx","skip-cert-verify":true,"network":"tcp","tls":true,"udp":true}
- {"type":"trojan","name":"v2rayse_test_4","server":"ca-trojan.bonds.id","port":443,"password":"bc7593fe-0604-4fbe--b4ab-11eb-b65e-1239d0255272","udp":true,"skip-cert-verify":true}
- {"type":"http","name":"http_proxy","server":"124.15.12.24","port":251,"username":"username","password":"password","udp":true}
- {"type":"socks5","name":"socks5_proxy","server":"124.15.12.24","port":2312,"udp":true}
- {"type":"socks5","name":"telegram_proxy","server":"1.2.3.4","port":123,"username":"username","password":"password","udp":true}
`
	serverImport.importClash(clashTest1, "clash_test")
}

func TestSub(t *testing.T) {
	proxyUrl = "socks5://127.0.0.1:1080"
	item := new(SubItem)
	item.Enabled = 1
	item.Key = "test_sub"
	item.Url = "https://raw.githubusercontent.com/freefq/free/master/v2"
	subManager.syncSub(item)
}

func TestPing(t *testing.T) {
	proxyUrl = "socks5://127.0.0.1:1080"
	item := new(ServerItem)
	item.Key = "test_sub"
	item.Remark = "测试"
	item.Url = "https://raw.githubusercontent.com/freefq/free/master/v2"
	item.Id = 9
	new(PingWorker).run(item)
}

func TestPingAll(t *testing.T) {
	v2rayCoreFile = "xray.exe"
	Ping.pingAll()
}

func TestToJson(t *testing.T) {
	items := getAllServers()
	for _, item := range items {
		fmt.Println("item", item)
		s := new(ServerToV2ray).toV2rayConfig(item)
		fmt.Println(s.config)
		fmt.Println(ToJson(s.config))
	}
}
