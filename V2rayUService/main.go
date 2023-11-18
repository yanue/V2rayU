package main

import (
	"context"
	"errors"
	"github.com/gin-gonic/gin"
	"log"
	"log/slog"
	"net/http"
	"time"
)

var logger *slog.Logger

func init() {
	log.SetFlags(log.Lshortfile | log.LstdFlags)
}

var proxyUrl string
var v2rayCoreFile string
var srv *http.Server
var api *ApiHandler

func init() {
	api = NewApiHandler()
}

func main() {
	initDb()
	Run(":11085")
}

func Run(addrPort string) {
	gin.SetMode(gin.ReleaseMode)

	// 初始化
	engine := gin.New()
	// 移除多余/路径
	engine.RemoveExtraSlash = true
	// 恢复中间件
	engine.Use(gin.Recovery())

	// web前端目录
	engine.Static("/static", "dist")

	// rest 接口路由
	// 前缀路径: /api
	g := engine.Group("/api")
	//api := r.Group("/api", TokenMiddleWare(s))

	// 1.基础服务
	g.GET("/config", api.GetConfig)
	g.GET("/server/list", api.GetServerList)
	g.GET("/server/stat", api.GetServerStat)
	g.POST("/server/import", api.Import)
	// 启动http server
	log.Println("running at:", addrPort)
	srv = &http.Server{
		Addr:    addrPort,
		Handler: engine,
	}
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("listen: %s\n", err)
	}
}

func Stop() {
	log.Println("-------- 正在清理 gin http server --------")
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("-------- 清理完毕 gin http server --------")
}
