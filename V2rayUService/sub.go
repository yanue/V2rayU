package main

import (
	"fmt"
	"io"
	"time"
)

type SubManager struct {
}

var subManager = new(SubManager)

func (s *SubManager) syncSubs() {
	fmt.Println("syncSubs")
	list := s.getAllSubs()
	fmt.Println("list", len(list))
	for _, item := range list {
		s.syncSub(item)
	}
}

func (s *SubManager) getAllSubs() (list []*SubItem) {
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

func (s *SubManager) syncSub(item *SubItem) {
	fmt.Println("syncSub", item.Id, item.Remark)
	if item.Enabled == 0 {
		fmt.Println("syncSub not enable", item.Id, item.Remark)
		return
	}
	client := newHttpClient(proxyUrl, 10*time.Second)
	resp, err := client.Get(item.Url)
	if err != nil {
		fmt.Println("sync sub error:", err)
		return
	}
	defer resp.Body.Close()
	bytes, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("sync sub error:", err)
		return
	}
	fmt.Println("sync sub success:", string(bytes))
	serverImport.importBySub(string(bytes), item)
}
