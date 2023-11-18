package main

import (
	"fmt"
)

func getAllServers() (list []*ServerItem) {
	query, err := db.Query(fmt.Sprintf("select %s from server_item order by id asc", serverItemPlaceholder))
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	for query.Next() {
		var item = new(ServerItem)
		err = query.Scan(
			&item.Id, &item.Key, &item.SubKey, &item.Type, &item.Remark, &item.Speed, &item.Url, &item.Json, &item.Address, &item.Port,
			&item.MixId, &item.AlterId, &item.Security, &item.Network, &item.HeaderType, &item.RequestHost, &item.Path, &item.StreamSecurity, &item.AllowInsecure, &item.Flow,
			&item.Sni, &item.Alpn, &item.Fingerprint, &item.PublicKey, &item.ShortId, &item.SpiderX,
		)
		if err != nil {
			fmt.Println("Error:", err)
		} else {
			list = append(list, item)
		}
	}
	return
}

func getAllSubs() (list []*SubItem) {
	query, err := db.Query("select _id,key,sub_type,remark,url,enabled,sort,auto_update_interval,update_time from sub_item order by sort asc")
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	for query.Next() {
		var item = new(SubItem)
		err = query.Scan(&item.Id, &item.Key, &item.SubType, &item.Remark, &item.Url, &item.Enabled, &item.Sort, &item.AutoUpdateInterval, &item.UpdateTime)
		if err != nil {
			fmt.Println("Error:", err)
		} else {
			list = append(list, item)

		}
	}
	return
}
