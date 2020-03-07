/**
 * Created by GoLand.
 * User: yanue
 * Date: 2019/2/28
 * Time: 17:34
 */

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"github.com/sparrc/go-ping"
	"io/ioutil"
	"net"
	"os"
	"sync"
	"time"
)

var host = ""
var port = ""
var file = ""
var help bool
var cmd string
var wait time.Duration

func init() {
	flag.BoolVar(&help, "help", false, "-help this help")
	flag.StringVar(&cmd, "cmd", "", "-cmd: ping or port")

	// for check port
	flag.StringVar(&host, "h", "", "-h host")
	flag.StringVar(&port, "p", "", "-p port")

	// for ping
	flag.StringVar(&file, "f", "", "-f file")
	flag.DurationVar(&wait, "t", 2*time.Second, "-t timeout for ping")

	flag.Usage = func() {
		fmt.Println(usage)
		flag.PrintDefaults()
	}
	flag.Parse()

	if help {
		flag.Usage()
	}
}

const usage = "V2rayUHelper - check port is free or ping multi host \nUsage: \n  V2rayUPort -cmd port -h host -p port\n  V2rayUPort -cmd ping -f file \n  Options:"

func main() {
	if len(os.Args) < 2 {
		flag.Usage()
		return
	}

	switch cmd {
	case "port":
		checkPort()
	case "ping":
		pingByFile()
	default:
		flag.Usage()
	}

	os.Exit(0)
}

func checkPort() {
	_, err := net.Listen("tcp", host+":"+port)
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	fmt.Println("ok")
	return
}

type Server struct {
	Name string `json:"name"`
	Host string `json:"host"`
	Ping string `json:"ping"`
}

var list []Server
var fastIdx int = -1
var fastSpeed time.Duration = 2 * time.Second

func pingByFile() {
	if len(file) == 0 {
		flag.Usage()
		return
	}

	txt, err := ioutil.ReadFile(file)
	if err != nil {
		fmt.Println("'error read:", err.Error())
		return
	}

	list = make([]Server, 0)

	err = json.Unmarshal(txt, &list)
	if err != nil {
		fmt.Println("error Unmarshal:", err.Error())
		return
	}

	fastSpeed = wait
	wg := &sync.WaitGroup{}
	for idx, item := range list {
		wg.Add(1)
		go pingHost(idx, item.Host, wg)
	}
	wg.Wait()

	txt, err = json.Marshal(list)
	if err != nil {
		fmt.Println("error Marshal:", err.Error())
		return
	}
	err = ioutil.WriteFile(file, txt, 0777)
	if err != nil {
		fmt.Println("error save:", err.Error())
		return
	}
	if fastIdx > -1 {
		item := list[fastIdx]
		fmt.Println("ok", item.Name)
		return
	}
	fmt.Println("error no found servers")
}

func pingHost(idx int, host string, wg *sync.WaitGroup) {
	defer wg.Done()

	pinger, err := ping.NewPinger(host)
	if err != nil {
		fmt.Printf("ERROR: %s\n", err.Error())
		return
	}

	pinger.OnRecv = func(pkt *ping.Packet) {
		//fmt.Printf("%d bytes from %s: icmp_seq=%d time=%v ttl=%v\n", pkt.Nbytes, pkt.IPAddr, pkt.Seq, pkt.Rtt, pkt.Ttl)
		if pkt.Rtt < fastSpeed {
			fastSpeed = pkt.Rtt
			fastIdx = idx
		}
		list[idx].Ping = fmt.Sprintf("%v", pkt.Rtt)
	}

	pinger.OnFinish = func(stats *ping.Statistics) {
	}

	pinger.Count = 1
	pinger.Interval = 1
	pinger.Timeout = wait
	pinger.SetPrivileged(false)

	pinger.Run()
}
