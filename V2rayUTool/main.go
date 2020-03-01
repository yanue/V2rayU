/**
 * Created by GoLand.
 * User: yanue
 * Date: 2019/2/28
 * Time: 17:34
 */

package main

import (
	"flag"
	"fmt"
	"net"
)

var host = ""
var port = ""

func init() {
	flag.StringVar(&host, "h", "", "-h host")
	flag.StringVar(&port, "p", "", "-p port")
	flag.Parse()
}

const help = "V2rayUPort - check port is free \nUsage: \n  V2rayUPort -h host -p port"

func main() {
	if len(host) == 0 || len(port) == 0 {
		fmt.Println(help)
		return
	}

	_, err := net.Listen("tcp", host+":"+port)
	if err != nil {
		fmt.Println("err:", err.Error())
		return
	}
	fmt.Println("ok")
}
