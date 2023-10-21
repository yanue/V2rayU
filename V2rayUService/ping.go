package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"net/http/httptrace"
	"os/exec"
	"sync"
	"time"
)

var Ping = new(PingManager)

const pingPool = 20

type PingManager struct {
	doing bool
}

func (s *PingManager) pingAll() {
	if s.doing {
		fmt.Println("pingAll doing")
		return
	}
	defer func() {
		s.doing = false
	}()
	s.doing = true
	// 启用20个并行执行ping
	ch := make(chan *ServerItem, pingPool)
	wg := &sync.WaitGroup{}
	wg.Add(pingPool)
	for i := 0; i < pingPool; i++ {
		go s.pingWorker(wg, ch, i)
	}
	// 分配任务
	items := getAllServers()
	fmt.Println("items", len(items))
	for _, item := range items {
		ch <- item
	}
	close(ch)
	// 等待任务完成
	wg.Wait()
}

func (s *PingManager) pingWorker(wg *sync.WaitGroup, ch chan *ServerItem, i int) {
	defer wg.Done()
	for item := range ch {
		new(PingWorker).run(item)
	}
}

type PingWorker struct {
	workerId int
	item     *ServerItem
	cmd      *exec.Cmd
	cancel   context.CancelFunc
	ctx      context.Context
	port     int
	config   string
}

func (s *PingWorker) run(item *ServerItem) {
	s.item = item
	// 创建文件
	s.createConfig()
	// 启动v2ray
	go s.runV2ray()
	// ping测试
	s.doPing()
	// 清理
	s.release()
}
func (s *PingWorker) createConfig() {
	s.port = 1080
	s.config = fmt.Sprintf(".config_%v.json", s.item.Id)
}

func (s *PingWorker) runV2ray() {
	configFile := fmt.Sprintf("%s", s.config)
	s.ctx, s.cancel = context.WithCancel(context.Background())
	s.cmd = exec.CommandContext(s.ctx, v2rayCoreFile, "-config", configFile)
	// 启动
	_ = s.cmd.Run()
}

// ping
func (s *PingWorker) doPing() {
	// Create trace struct.
	proxyUrl := fmt.Sprintf("socks5://127.0.0.1:%v", s.port)
	client := newHttpClient(proxyUrl, 2*time.Second)
	// Prepare request with trace attached to it.
	req, err := http.NewRequest(http.MethodGet, "http://www.gstatic.com/generate_204", nil)
	if err != nil {
		log.Fatalln("request error", err)
	}
	var startMs = time.Now().UnixMilli()
	var endMs int64
	// Attach trace.
	req = req.WithContext(httptrace.WithClientTrace(req.Context(), &httptrace.ClientTrace{
		WroteRequest: func(wr httptrace.WroteRequestInfo) {
			startMs = time.Now().UnixMilli()
		},
		GotFirstResponseByte: func() {
			endMs = time.Now().UnixMilli()
		},
	}))
	// Make a request.
	res, err := client.Do(req)
	if err != nil {
		s.item.updateSpeed(int(-1))
		fmt.Println("failed", s.item.Id, s.item.Remark, err)
		return
	}
	_ = res.Body.Close()
	if endMs == 0 {
		endMs = time.Now().UnixMilli()
	}
	spent := endMs - startMs
	fmt.Println("spent", spent, s.item.Id, res.StatusCode, s.item.Remark)
	// 更新ping值
	s.item.updateSpeed(int(spent))
	// 杀进程
}

func (s *PingWorker) release() {
	if s.cancel != nil {
		s.cancel()
	}
	if s.cmd != nil {
		if s.cmd.Process != nil {
			_ = s.cmd.Process.Kill()
		}
		if s.cmd.ProcessState != nil {
			_ = s.cmd.Process.Kill()
		}
	}
}
