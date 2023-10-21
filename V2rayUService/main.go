package main

import (
	"log"
)

func init() {
	log.SetFlags(log.Lshortfile | log.LstdFlags)
}

var proxyUrl string
var v2rayCoreFile string

func main() {
	initDb()
}
