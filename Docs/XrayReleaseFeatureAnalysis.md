# Xray Release Feature Analysis

- Generated at: `2026-05-18 13:45:27Z`
- Data source: `https://api.github.com/repos/XTLS/Xray-core/releases`
- Pages fetched: up to `5` pages × `100` items
- Releases analyzed: `114`

> 说明：本报告只分析 GitHub Releases API 中的 release 标题与正文提及情况。
> 它可以作为**版本线索**与**功能演进证据**，但不应单独视为“官方完整支持列表”或“精确首发版本”的唯一依据。
> 更稳妥的做法是：**官方 docs 主列表确定当前支持面，releases API 辅助判断版本演进**。

## Summary

| Feature | Match count | First matched release | Last matched release | Note |
|---|---:|---|---|---|
| XHTTP | 22 | `v1.8.16` | `v26.3.27` | 重点用于分析新 transport 的引入/演进。 |
| REALITY | 28 | `v1.7.5` | `v26.3.27` | 用于观察 REALITY 相关 release 线索。 |
| Hysteria | 3 | `v26.1.23` | `v26.3.27` | 用于观察 Hysteria inbound/outbound/transport 的 release 线索。 |
| WireGuard | 22 | `v1.5.6` | `v26.3.27` | 用于观察 WireGuard inbound/outbound 的 release 线索。 |
| gRPC | 18 | `v1.4.0` | `v26.3.27` | 用于观察 gRPC transport 的 release 线索。 |
| WebSocket | 15 | `v1.1.4` | `v26.3.27` | 用于观察 WebSocket transport 的 release 线索。 |
| HTTPUpgrade | 6 | `v1.8.9` | `v26.3.27` | 用于观察 HTTPUpgrade transport 的 release 线索。 |
| FinalMask | 2 | `v26.2.6` | `v26.3.27` | 用于观察附加配置 FinalMask 的 release 线索。 |
| Sockopt | 19 | `v1.4.0` | `v26.1.23` | 用于观察 Sockopt 的 release 线索。 |

## Details

### XHTTP

- Note: 重点用于分析新 transport 的引入/演进。
- Match count: `22`
- First matched release in fetched dataset: `v1.8.16`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - ## Finalmask, mKCP, Hysteria, XHTTP, REALITY, TLS ECH, WireGuard, VLESS Reverse Proxy, Global HTTP headers' browser masquerading, API, Others
  - - **新增 header-custom (TCP & UDP)、Sudoku (TCP & UDP)，移植了 Direct/Freedom 出站的 fragment (TCP)、noise (UDP)，最终的自定义流量外观拥有了更多可能，且均支持通过 `fm` 参数分享，基于 Xray-core 的 GUI 应尽快更新 Finalmask（类似 XHTTP extra）**
  - - 支持了 dialer-proxy，补上了 XHTTP/3，加上一众 TCP 协议/传输层，至此 Xray 产生的所有代理流量均能被 Finalmask
- `v26.2.6` · 2026-02-06 · [Xray-core v26.2.6](https://github.com/XTLS/Xray-core/releases/tag/v26.2.6)
  - ## XHTTP transport: New options for bypassing CDN's potential detection https://github.com/XTLS/Xray-core/pull/5414 & Finalmask: Add [XICMP](https://github.com/XTLS/Xray-core/pull/5633), [XDNS](https://github.com/XTLS/Xray-core/pull/5560) (relies on mKCP, like DNSTT), header-\*, mkcp-\*
  - 1. **XHTTP 新增了一些选项，以绕过潜在的 CDN 检测（尚未定型，不建议第三方实现现在跟进），详见 https://github.com/XTLS/Xray-core/pull/5414**
  - - **Related links: [VLESS Post-Quantum Encryption](https://github.com/XTLS/Xray-core/pull/5067), [XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113), [Announcement of NFTs by Project X](https://github.com/XTLS/Xray-core/discussions/3633)**
- `v26.1.23` · 2026-01-23 · [Xray-core v26.1.23](https://github.com/XTLS/Xray-core/releases/tag/v26.1.23)
  - - **Related links: [VLESS Post-Quantum Encryption](https://github.com/XTLS/Xray-core/pull/5067), [XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113), [Announcement of NFTs by Project X](https://github.com/XTLS/Xray-core/discussions/3633)**
  - * XHTTP server: Fix ScStreamUpServerSecs' non-default value by @fanymagnet in https://github.com/XTLS/Xray-core/pull/5486
- `v25.12.8` · 2025-12-08 · [Xray-core v25.12.8](https://github.com/XTLS/Xray-core/releases/tag/v25.12.8)
  - 2. **服务端 sockopt 加了 `trustedXForwardedFor` 以防止 XHTTP、WS、HU 客户端伪造源 IP，详见 https://github.com/XTLS/Xray-core/pull/5331**
  - - **Related links: [VLESS Post-Quantum Encryption](https://github.com/XTLS/Xray-core/pull/5067), [XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113), [Announcement of NFTs by Project X](https://github.com/XTLS/Xray-core/discussions/3633)**
  - * Sockopt config: Add `trustedXForwardedFor` (for XHTTP, WS, HU inbounds) by @RPRX in https://github.com/XTLS/Xray-core/pull/5331
- `v25.10.15` · 2025-10-15 · [Xray-core v25.10.15](https://github.com/XTLS/Xray-core/releases/tag/v25.10.15)
  - 3. 看到很多小白不会配置 XHTTP XMUX 还抱怨测速不理想，索性把 `maxConcurrency` 默认改为了 1 试试
  - * XHTTP client: Change default `maxConcurrency` to 1 for speed testing by @RPRX in https://github.com/XTLS/Xray-core/commit/9cc7907234a8297a87a0ff77fc40db373b74a0f2
- `v25.9.5` · 2025-09-05 · [Xray-core v25.9.5](https://github.com/XTLS/Xray-core/releases/tag/v25.9.5)
  - - **建议开 XTLS 避免二次加解密（native/xorpub 可自动 ReadV/Splice），可再叠上 XHTTP、WS 等传输层，详见 https://github.com/XTLS/Xray-core/pull/5067**
  - * XHTTP client: Fix edge-case issue for `packet-up` mode by @Fangliding in https://github.com/XTLS/Xray-core/pull/5020
- `v25.5.16` · 2025-05-16 · [Xray-core v25.5.16](https://github.com/XTLS/Xray-core/releases/tag/v25.5.16)
  - > **Shadowrocket TF 版已支持 XHTTP**，大家可以测测，如果有问题请反馈过去
  - 此外从上个版本开始，auto mode 的 XHTTP TLS 默认改为 packet-up，XHTTP REALITY 默认仍为 stream-one
  - * XHTTP client: Set packet-up as the default `mode` (auto) when using TLS by @RPRX in https://github.com/XTLS/Xray-core/commit/0995fa41fe692e332412670665bd934e4c734caa
- `v25.4.30` · 2025-04-30 · [Xray-core v25.4.30](https://github.com/XTLS/Xray-core/releases/tag/v25.4.30)
  - **Xray-core 四月累积更新版本，主要包含大量修复，以及 XHTTP TLS 默认改为 packet-up，XHTTP REALITY 默认仍为 stream-one**
  - > **小火箭 TF 版已支持 XHTTP**，大家可以测测，如果有问题请反馈过去

### REALITY

- Note: 用于观察 REALITY 相关 release 线索。
- Match count: `28`
- First matched release in fetched dataset: `v1.7.5`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - ## Finalmask, mKCP, Hysteria, XHTTP, REALITY, TLS ECH, WireGuard, VLESS Reverse Proxy, Global HTTP headers' browser masquerading, API, Others
  - ### REALITY https://github.com/XTLS/Xray-core/commit/157e65b34d32363528088c592d4e415d84f01a63 https://github.com/XTLS/Xray-core/commit/2320416ca3869d7818b9d86b749259a75fd3e103 https://github.com/XTLS/Xray-core/pull/5738 https://github.com/XTLS/Xray-core/pull/5759
  - - **REALITY NFT: https://opensea.io/item/ethereum/0x5ee362866001613093361eb8569d59c4141b76d1/2**
- `v26.2.6` · 2026-02-06 · [Xray-core v26.2.6](https://github.com/XTLS/Xray-core/releases/tag/v26.2.6)
  - > https://t.me/projectXtls/1478 不在乎主动探测的话其实最简单的方法就是 REALITY 加随便填 SNI，服务端允许的值和客户端填写的值对得上就行，不需要自签再 pin 那么麻烦，且几乎所有客户端都支持 REALITY 及其分享，~~这不比自签强吗~~
  - - **REALITY NFT: https://opensea.io/item/ethereum/0x5ee362866001613093361eb8569d59c4141b76d1/2**
  - - **Related links: [VLESS Post-Quantum Encryption](https://github.com/XTLS/Xray-core/pull/5067), [XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113), [Announcement of NFTs by Project X](https://github.com/XTLS/Xray-core/discussions/3633)**
- `v26.1.23` · 2026-01-23 · [Xray-core v26.1.23](https://github.com/XTLS/Xray-core/releases/tag/v26.1.23)
  - 6. REALITY 客户端收到目标网站的真证书时打印出更加明确的警报（potential MITM or redirection）https://github.com/XTLS/Xray-core/pull/5427
  - - **REALITY NFT: https://opensea.io/item/ethereum/0x5ee362866001613093361eb8569d59c4141b76d1/2**
  - - **Related links: [VLESS Post-Quantum Encryption](https://github.com/XTLS/Xray-core/pull/5067), [XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113), [Announcement of NFTs by Project X](https://github.com/XTLS/Xray-core/discussions/3633)**
- `v25.12.8` · 2025-12-08 · [Xray-core v25.12.8](https://github.com/XTLS/Xray-core/releases/tag/v25.12.8)
  - - **REALITY NFT: https://opensea.io/item/ethereum/0x5ee362866001613093361eb8569d59c4141b76d1/2**
  - - **Related links: [VLESS Post-Quantum Encryption](https://github.com/XTLS/Xray-core/pull/5067), [XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113), [Announcement of NFTs by Project X](https://github.com/XTLS/Xray-core/discussions/3633)**
  - * REALITY config: Return error when short id is too long by @Fangliding @RPRX in https://github.com/XTLS/Xray-core/pull/5276
- `v25.10.15` · 2025-10-15 · [Xray-core v25.10.15](https://github.com/XTLS/Xray-core/releases/tag/v25.10.15)
  - * transport/internet/reality/reality.go: Safely get negotiated CurveID in VerifyPeerCertificate() by @RPRX in https://github.com/XTLS/Xray-core/commit/40f0a541bf8de347b00f6ca980279d7b0d5e6af4
- `v25.9.11` · 2025-09-10 · [Xray-core v25.9.11](https://github.com/XTLS/Xray-core/releases/tag/v25.9.11)
  - > **这个 PR 的目的就是为了让 Xray 更适合做反向代理 / 内网穿透，独特的优势是你可以直接复用拿来翻墙的那台 VPS、复用 REALITY 的抗量子加密且防封，因为 REALITY 不仅可以稳定地穿透 GFW，也可以穿透公司网络那些奇奇怪怪的审计**
  - * Update github.com/xtls/reality to 20250904214705 by @RPRX in https://github.com/XTLS/Xray-core/commit/4ae497106d3e0e6d66c0c75fc2ba297d9db37acc
- `v25.9.5` · 2025-09-05 · [Xray-core v25.9.5](https://github.com/XTLS/Xray-core/releases/tag/v25.9.5)
  - * Update github.com/xtls/reality to 20250828044527 by @RPRX in https://github.com/XTLS/Xray-core/commit/12b077f33b766952fa6640104d93d68803b7feee
- `v25.8.3` · 2025-08-03 · [Xray-core v25.8.3](https://github.com/XTLS/Xray-core/releases/tag/v25.8.3)
  - 本次久违地放出了一些 REALITY NFT 和几个 Project X NFT
  - **请支持一个 REALITY NFT：https://opensea.io/assets/ethereum/0x5ee362866001613093361eb8569d59c4141b76d1/2**

### Hysteria

- Note: 用于观察 Hysteria inbound/outbound/transport 的 release 线索。
- Match count: `3`
- First matched release in fetched dataset: `v26.1.23`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - ## Finalmask, mKCP, Hysteria, XHTTP, REALITY, TLS ECH, WireGuard, VLESS Reverse Proxy, Global HTTP headers' browser masquerading, API, Others
  - ### Hysteria https://github.com/XTLS/Xray-core/pull/5679 https://github.com/XTLS/Xray-core/pull/5782 https://github.com/XTLS/Xray-core/pull/5772
  - - **新增 Hysteria 2 入站与传输层，~~至此 Xray 支持了完整的 Hysteria 2，甚至 Finalmask 不只有 Salamander~~**
- `v26.2.6` · 2026-02-06 · [Xray-core v26.2.6](https://github.com/XTLS/Xray-core/releases/tag/v26.2.6)
  - * Hysteria transport: Support range & random for `interval` in `udphop` as well by @LjhAUMEM in https://github.com/XTLS/Xray-core/pull/5603
- `v26.1.23` · 2026-01-23 · [Xray-core v26.1.23](https://github.com/XTLS/Xray-core/releases/tag/v26.1.23)
  - ## Proxy: Add TUN inbound for Windows & Linux, including Android https://github.com/XTLS/Xray-core/pull/5464 https://github.com/XTLS/Xray-core/pull/5509 & Proxy: Add Hysteria outbound & transport (version 2, udphop) and Salamander udpmask https://github.com/XTLS/Xray-core/pull/5508
  - 3. **新增 Hysteria 2 出站、Hysteria 2 传输层（支持端口跳跃）、Salamander 伪装层，完整配置示例详见 https://github.com/XTLS/Xray-core/pull/5508**
  - * Proxy: Add Hysteria outbound & transport (version 2, udphop) and Salamander udpmask by @LjhAUMEM in https://github.com/XTLS/Xray-core/pull/5508

### WireGuard

- Note: 用于观察 WireGuard inbound/outbound 的 release 线索。
- Match count: `22`
- First matched release in fetched dataset: `v1.5.6`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - ## Finalmask, mKCP, Hysteria, XHTTP, REALITY, TLS ECH, WireGuard, VLESS Reverse Proxy, Global HTTP headers' browser masquerading, API, Others
  - ### WireGuard https://github.com/XTLS/Xray-core/pull/5833 https://github.com/XTLS/Xray-core/pull/5554 https://github.com/XTLS/Xray-core/pull/5843
    - - **出入站 UDP 均实现了 FullCone，提醒一下结合 Finalmask 后它拥有比其它 WireGuard 变种更强的伪装效果**
- `v26.2.6` · 2026-02-06 · [Xray-core v26.2.6](https://github.com/XTLS/Xray-core/releases/tag/v26.2.6)
  - 4. **Finalmask UDP 支持了 WireGuard、SS AEAD/2022 等代理层协议产生的 UDP 流量，详见 https://github.com/XTLS/Xray-core/pull/5643**
  - * Finalmask: Add XICMP (relies on mKCP/QUIC or WireGuard) by @LjhAUMEM in https://github.com/XTLS/Xray-core/pull/5633
  - * Finalmask UDP: Support WireGuard & Shadowsocks AEAD/2022 by @LjhAUMEM in https://github.com/XTLS/Xray-core/pull/5643
- `v26.1.23` · 2026-01-23 · [Xray-core v26.1.23](https://github.com/XTLS/Xray-core/releases/tag/v26.1.23)
  - * Wireguard: Decouple server endpoint DNS from address option by @Meo597 in https://github.com/XTLS/Xray-core/pull/5417
- `v25.12.8` · 2025-12-08 · [Xray-core v25.12.8](https://github.com/XTLS/Xray-core/releases/tag/v25.12.8)
  - * Fix wireguard not discarding broken connection on android by @Exclude0122 in https://github.com/XTLS/Xray-core/pull/5304
- `v25.9.5` · 2025-09-05 · [Xray-core v25.9.5](https://github.com/XTLS/Xray-core/releases/tag/v25.9.5)
  - * Wireguard inbound: Fix context sharing problem by @yuhan6665 in https://github.com/XTLS/Xray-core/pull/4988
  - * WireGuard outbound: Fix close closed by @Fangliding in https://github.com/XTLS/Xray-core/pull/5054
- `v25.5.16` · 2025-05-16 · [Xray-core v25.5.16](https://github.com/XTLS/Xray-core/releases/tag/v25.5.16)
  - * WireGuard: Improve config error handling; Prevent panic in case of errors during server initialization by @IlyaGulya in https://github.com/XTLS/Xray-core/pull/4566
- `v24.12.18` · 2024-12-18 · [Xray-core v24.12.18](https://github.com/XTLS/Xray-core/releases/tag/v24.12.18)
  - * WireGuard inbound: Add missing inbound session information back by @Fangliding in https://github.com/XTLS/Xray-core/pull/4126
- `v24.11.21` · 2024-11-21 · [Xray-core v24.11.21](https://github.com/XTLS/Xray-core/releases/tag/v24.11.21)
  - * WireGuard kernelTun: Fix multi-outbounds not work by @Fangliding in https://github.com/XTLS/Xray-core/pull/4015
  - * WireGuard inbound: Fix leaking session information between requests by @Fangliding in https://github.com/XTLS/Xray-core/pull/4030

### gRPC

- Note: 用于观察 gRPC transport 的 release 线索。
- Match count: `18`
- First matched release in fetched dataset: `v1.4.0`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - - **XHTTP、WS、HU、gRPC 传输层可设置 `headers` `User-Agent` 来指定 "firefox"/"edge"/"golang"**
  - * gRPC client: Strip "grpc-go/version" suffix from User-Agent header by @RPRX in https://github.com/XTLS/Xray-core/pull/5689
- `v24.11.21` · 2024-11-21 · [Xray-core v24.11.21](https://github.com/XTLS/Xray-core/releases/tag/v24.11.21)
  - ## XHTTP client: Add gRPC header to "stream-up" mode by default #4042
  - 这个版本为 stream-up 模式的上行 POST 请求默认加上了 gRPC 标头，**经测试 CF H2 支持它，详见 #4042**
  - * XHTTP client: Add gRPC header to "stream-up" mode by default by @RPRX in https://github.com/XTLS/Xray-core/pull/4042
- `v24.11.11` · 2024-11-11 · [Xray-core v24.11.11](https://github.com/XTLS/Xray-core/releases/tag/v24.11.11)
  - **XHTTP stream-up 模式旨在取代现有的 H2 / gRPC over REALITY，XHTTP 有 header padding、XMUX，表现会更好**
  - 总之，现在正式建议现有的 H2、gRPC 均迁移至 XHTTP，~~并玩一玩上下行分离~~，尤其是 H2，它仍有可能被移除
- `v24.10.31` · 2024-10-31 · [Xray-core v24.10.31](https://github.com/XTLS/Xray-core/releases/tag/v24.10.31)
  - * Transport: Remove GUN (an alias of gRPC) by @RPRX in https://github.com/XTLS/Xray-core/commit/8809cbda817006f8d33c4c9993014d146f7e1138
- `v1.8.16` · 2024-06-21 · [Xray-core v1.8.16](https://github.com/XTLS/Xray-core/releases/tag/v1.8.16)
  - SplitHTTP 使用 HTTP GET 长连接传输下行流量，使用多个 HTTP POST 请求传输上行流量，**可以通过不支持 WebSocket、gRPC 的 CDN**，实现与 Meek 相同的目标，但 SplitHTTP 是从零开始设计的全新传输方式，并非基于 Meek 修改而来，**且 SplitHTTP 比 Meek 更简单、效率更高**，详见文档 [英文（原生文档）](https://xtls.github.io/en/config/transports/splithttp.html) [中文（内容略有不同）](https://xtls.github.io/config/transports/splithttp.html)
- `v1.8.10` · 2024-03-30 · [Xray-core v1.8.10](https://github.com/XTLS/Xray-core/releases/tag/v1.8.10)
  - - gRPC API 现支持增删路由规则 #3189 @hossinasaadi
- `v1.8.9` · 2024-03-11 · [Xray-core v1.8.9](https://github.com/XTLS/Xray-core/releases/tag/v1.8.9)
  - - #716 gRPC 新增 `authority` #3076，**修订 `serviceName` 必须使用 `encodeURIComponent` 转义 #1815**
  - - gRPC 传输方式支持设置 `authority`（类似 `Host`） #3076 @RPRX
- `v1.8.4` · 2023-08-29 · [Xray-core v1.8.4](https://github.com/XTLS/Xray-core/releases/tag/v1.8.4)
  - - 修复 gRPC 使用 dialerProxy 代理链 d92002ad127f64bc1e740cb350eafd693ffadd6d @RPRX

### WebSocket

- Note: 用于观察 WebSocket transport 的 release 线索。
- Match count: `15`
- First matched release in fetched dataset: `v1.1.4`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - - 避免了 WSS & HUS 的 outer ALPN 仍为 http/1.1，~~虽然这一行为与浏览器不同但 ALPN http/1.1 会被重点关照所以~~
  - - **XHTTP、WS、HU、gRPC 传输层可设置 `headers` `User-Agent` 来指定 "firefox"/"edge"/"golang"**
  - * TLS ECH: Avoid outer ALPN http/1.1 for WSS & HUS; Change `echForceQuery`'s default value to "full"; Update github.com/refraction-networking/utls to 20260301010127; Add irrelevant tests for uTLS-REALITY by @Fangliding in https://github.com/XTLS/Xray-core/pull/5725
- `v25.12.8` · 2025-12-08 · [Xray-core v25.12.8](https://github.com/XTLS/Xray-core/releases/tag/v25.12.8)
  - 2. **服务端 sockopt 加了 `trustedXForwardedFor` 以防止 XHTTP、WS、HU 客户端伪造源 IP，详见 https://github.com/XTLS/Xray-core/pull/5331**
  - * Sockopt config: Add `trustedXForwardedFor` (for XHTTP, WS, HU inbounds) by @RPRX in https://github.com/XTLS/Xray-core/pull/5331
- `v25.9.5` · 2025-09-05 · [Xray-core v25.9.5](https://github.com/XTLS/Xray-core/releases/tag/v25.9.5)
  - - **建议开 XTLS 避免二次加解密（native/xorpub 可自动 ReadV/Splice），可再叠上 XHTTP、WS 等传输层，详见 https://github.com/XTLS/Xray-core/pull/5067**
- `v24.12.18` · 2024-12-18 · [Xray-core v24.12.18](https://github.com/XTLS/Xray-core/releases/tag/v24.12.18)
  - * XHTTP, WS, HU: Forbid "host" in `headers`, read `serverName` instead by @RPRX in https://github.com/XTLS/Xray-core/pull/4142
  - * WebSocket config: Fix `headers` by @rosebe in https://github.com/XTLS/Xray-core/pull/4177
- `v24.11.30` · 2024-11-30 · [Xray-core v24.11.30](https://github.com/XTLS/Xray-core/releases/tag/v24.11.30)
  - * WebSocket config: Add `heartbeatPeriod` for client & server by @hr567 @RPRX in https://github.com/XTLS/Xray-core/pull/4065
- `v1.8.23` · 2024-07-29 · [Xray-core v1.8.23](https://github.com/XTLS/Xray-core/releases/tag/v1.8.23)
  - - WS, HU: Remove unnecessary sleep from test #3600 @mmmray
- `v1.8.21` · 2024-07-21 · [Xray-core v1.8.21](https://github.com/XTLS/Xray-core/releases/tag/v1.8.21)
  - - 修复 `WebSocket` 读取了 HTTP 头 X-Forwarded-For 但未传递的问题 #3546 @Fangliding @mmmray
  - - HTTP 相关传输（`WS` `H2` `HTTPUpgrade` `SplitHTTP`）host 容许客户端发送端口 https://github.com/XTLS/Xray-core/issues/3222#issuecomment-2212334502 @cute @yuhan6665
- `v1.8.16` · 2024-06-21 · [Xray-core v1.8.16](https://github.com/XTLS/Xray-core/releases/tag/v1.8.16)
  - SplitHTTP 使用 HTTP GET 长连接传输下行流量，使用多个 HTTP POST 请求传输上行流量，**可以通过不支持 WebSocket、gRPC 的 CDN**，实现与 Meek 相同的目标，但 SplitHTTP 是从零开始设计的全新传输方式，并非基于 Meek 修改而来，**且 SplitHTTP 比 Meek 更简单、效率更高**，详见文档 [英文（原生文档）](https://xtls.github.io/en/config/transports/splithttp.html) [中文（内容略有不同）](https://xtls.github.io/config/transports/splithttp.html)
  - 此外，SplitHTTP 没有 WebSocket 的 ALPN 问题，这是一大优势，未来还会支持 HTTP/3（QUIC）
  - - 更新 WebSocket、HTTPUpgrade 测试代码 #3414 https://github.com/XTLS/Xray-core/commit/be29cc39d7b63f4a77ca97881ff62b61bc1b9cb6 @Fangliding

### HTTPUpgrade

- Note: 用于观察 HTTPUpgrade transport 的 release 线索。
- Match count: `6`
- First matched release in fetched dataset: `v1.8.9`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - * HTTPUpgrade server: Fix certain stuck in Handle() by @Fangliding in https://github.com/XTLS/Xray-core/pull/5661
- `v1.8.21` · 2024-07-21 · [Xray-core v1.8.21](https://github.com/XTLS/Xray-core/releases/tag/v1.8.21)
  - - HTTP 相关传输（`WS` `H2` `HTTPUpgrade` `SplitHTTP`）host 容许客户端发送端口 https://github.com/XTLS/Xray-core/issues/3222#issuecomment-2212334502 @cute @yuhan6665
- `v1.8.16` · 2024-06-21 · [Xray-core v1.8.16](https://github.com/XTLS/Xray-core/releases/tag/v1.8.16)
  - - `HTTPUpgrade` 使用自定义 `headers` 可以保持大小写 #3427 #3430 @mmmray @Fangliding
  - - `HTTPUpgrade` 缓存可以正确释放 #3428 @mmmray
  - - 更新 WebSocket、HTTPUpgrade 测试代码 #3414 https://github.com/XTLS/Xray-core/commit/be29cc39d7b63f4a77ca97881ff62b61bc1b9cb6 @Fangliding
- `v1.8.11` · 2024-04-26 · [Xray-core v1.8.11](https://github.com/XTLS/Xray-core/releases/tag/v1.8.11)
  - - HTTPUpgrade 允许默认设置 #3245 @Fangliding
  - - HTTPUpgrade 的一些日志 @X-Oracle
- `v1.8.10` · 2024-03-30 · [Xray-core v1.8.10](https://github.com/XTLS/Xray-core/releases/tag/v1.8.10)
  - ## HTTPUpgrade 0-RTT
  - > **现在在 HTTPUpgrade path 后加上 `?ed=2560` 才会启用 0-RTT**
  - - HTTPUpgrade 现支持自定义头 #3170 @Fangliding
- `v1.8.9` · 2024-03-11 · [Xray-core v1.8.9](https://github.com/XTLS/Xray-core/releases/tag/v1.8.9)
  - - #716 新增 `HTTPUpgrade` 传输方式
  - - 新增 `HTTPUpgrade` 传输方式 [Xray 文档](https://xtls.github.io/config/transports/httpupgrade.html) @maskedeken @xiaokangwang

### FinalMask

- Note: 用于观察附加配置 FinalMask 的 release 线索。
- Match count: `2`
- First matched release in fetched dataset: `v26.2.6`
- Last matched release in fetched dataset: `v26.3.27`

Sample matched releases:

- `v26.3.27` · 2026-03-27 · [Xray-core v26.3.27](https://github.com/XTLS/Xray-core/releases/tag/v26.3.27)
  - ## Finalmask, mKCP, Hysteria, XHTTP, REALITY, TLS ECH, WireGuard, VLESS Reverse Proxy, Global HTTP headers' browser masquerading, API, Others
  - ### Finalmask https://github.com/XTLS/Xray-core/pull/5657 https://github.com/XTLS/Xray-core/pull/5685 https://github.com/XTLS/Xray-core/pull/5812 https://github.com/XTLS/Xray-core/pull/5850
  - - **新增 header-custom (TCP & UDP)、Sudoku (TCP & UDP)，移植了 Direct/Freedom 出站的 fragment (TCP)、noise (UDP)，最终的自定义流量外观拥有了更多可能，且均支持通过 `fm` 参数分享，基于 Xray-core 的 GUI 应尽快更新 Finalmask（类似 XHTTP extra）**
- `v26.2.6` · 2026-02-06 · [Xray-core v26.2.6](https://github.com/XTLS/Xray-core/releases/tag/v26.2.6)
  - ## XHTTP transport: New options for bypassing CDN's potential detection https://github.com/XTLS/Xray-core/pull/5414 & Finalmask: Add [XICMP](https://github.com/XTLS/Xray-core/pull/5633), [XDNS](https://github.com/XTLS/Xray-core/pull/5560) (relies on mKCP, like DNSTT), header-\*, mkcp-\*
  - 3. **Finalmask UDP 新增了 [XICMP](https://github.com/XTLS/Xray-core/pull/5633)、[XDNS](https://github.com/XTLS/Xray-core/pull/5560)、header-\*、mkcp-\*，分享链接标准 https://github.com/XTLS/Xray-core/discussions/716 已更新 `fm`、`pcs`、`vcn`**
  - 4. **Finalmask UDP 支持了 WireGuard、SS AEAD/2022 等代理层协议产生的 UDP 流量，详见 https://github.com/XTLS/Xray-core/pull/5643**

### Sockopt

- Note: 用于观察 Sockopt 的 release 线索。
- Match count: `19`
- First matched release in fetched dataset: `v1.4.0`
- Last matched release in fetched dataset: `v26.1.23`

Sample matched releases:

- `v26.1.23` · 2026-01-23 · [Xray-core v26.1.23](https://github.com/XTLS/Xray-core/releases/tag/v26.1.23)
  - 2. 为所有出站设置 `sockopt` `"interface": "WLAN"` 或 "以太网" 防止出站回流 Xray-core
- `v25.12.8` · 2025-12-08 · [Xray-core v25.12.8](https://github.com/XTLS/Xray-core/releases/tag/v25.12.8)
  - 2. **服务端 sockopt 加了 `trustedXForwardedFor` 以防止 XHTTP、WS、HU 客户端伪造源 IP，详见 https://github.com/XTLS/Xray-core/pull/5331**
  - * Sockopt config: Add `trustedXForwardedFor` (for XHTTP, WS, HU inbounds) by @RPRX in https://github.com/XTLS/Xray-core/pull/5331
- `v25.5.16` · 2025-05-16 · [Xray-core v25.5.16](https://github.com/XTLS/Xray-core/releases/tag/v25.5.16)
  - * Sockopt: Fix Windows UDP `interface` bind; Allow Linux `customSockopt` work for UDP by @Fangliding in https://github.com/XTLS/Xray-core/pull/4504
  - * Sockopt: Fix Windows Multicast `interface` bind by @xqzr in https://github.com/XTLS/Xray-core/pull/4568
  - * Sockopt: Fix Darwin (macOS, iOS...) UDP `interface` bind by @92613hjh in https://github.com/XTLS/Xray-core/pull/4530
- `v25.3.31` · 2025-03-31 · [Xray-core v25.3.31](https://github.com/XTLS/Xray-core/releases/tag/v25.3.31)
  - **Xray-core 三月累积更新版本，主要包含大量针对 DNS 和 sockopt 的增强，以及其它几处修复，感谢各位贡献者**
- `v25.3.6` · 2025-03-06 · [Xray-core v25.3.6](https://github.com/XTLS/Xray-core/releases/tag/v25.3.6)
  - * Sockopt config: Add `penetrate` for XHTTP U-D-S, Remove `tcpNoDelay` by @RPRX in https://github.com/XTLS/Xray-core/commit/369d8944cf3773300eb8dad3f909957e5705fc49
  - * Sockopt: Add `addressPortStrategy` (query SRV or TXT) by @j3l11234 @Fangliding in https://github.com/XTLS/Xray-core/pull/4416
- `v24.12.18` · 2024-12-18 · [Xray-core v24.12.18](https://github.com/XTLS/Xray-core/releases/tag/v24.12.18)
  - * XHTTP `downloadSettings`: Inherit `sockopt` if its own doesn't exist (e.g., in `extra`) by @RPRX in https://github.com/XTLS/Xray-core/commit/9dbdf92c2728070e3e58008598880eb2e9f79188
- `v1.8.21` · 2024-07-21 · [Xray-core v1.8.21](https://github.com/XTLS/Xray-core/releases/tag/v1.8.21)
  - - 新增自定义 `sockopt` 选项 #3517 @Fangliding
- `v1.8.8` · 2024-02-25 · [Xray-core v1.8.8](https://github.com/XTLS/Xray-core/releases/tag/v1.8.8)
  - - sockopt 选项对 UDP 连接生效 #3002 @Fangliding @dyhkwong

## Suggested usage in V2rayU

1. 用官方 docs 主列表判断 **当前是否支持**。
2. 用本报告判断 **某功能从哪些 release 开始频繁出现**。
3. 只有当 release note 与 docs/源码/兼容经验三者都能互相印证时，才把规则提升为启动前的**硬版本门槛**。
