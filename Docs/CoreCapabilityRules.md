# Xray 功能支持规则（Capability Rules）

本文件改为**严格区分三类信息**：

1. **当前官方文档主列表**里明确列出的功能
2. **历史/兼容页面**里仍可见，但已不在当前主列表中的功能
3. **V2rayU 自己额外做的兼容判断**（只保留少量有明确依据或已有实现依赖的规则）

> 说明：此前文档里把很多功能写成 `>= 1.0.0`、`Never`、`v25+ 移除`，其中不少并不能从当前官方文档直接推出，且有的结论已经和当前官方文档冲突。
>
> 例如：当前官方文档（2026-05）里，`WebSocket`、`gRPC`、`Hysteria inbound/outbound`、`WireGuard inbound/outbound` 都**明确仍在主列表中**，因此不能继续写成“从未支持”或“已经下架”。

---

## 1. 取证来源

本功能支持规则目前以 XTLS 官方文档站为主：

- 入站协议总览：`https://xtls.github.io/config/inbounds/`
- 出站协议总览：`https://xtls.github.io/config/outbounds/`
- 传输配置总览：`https://xtls.github.io/config/transports/`
- RAW 页面（用户提供）：`https://xtls.github.io/config/transports/raw.html`
- GitHub Releases API：`https://api.github.com/repos/XTLS/Xray-core/releases`

本次核对时可见的页面更新时间：

- `inbounds`：2026-03-28
- `outbounds`：2026-01-18
- `transports`：2026-05-09
- `raw`：2026-05-07

此外，仓库内已提供一份基于 releases API 自动生成的分析报告：

- `Docs/XrayReleaseFeatureAnalysis.md`
- 生成脚本：`Tools/analyze_xray_releases.py`

---

## 2. Releases API 分析：可作为版本演进线索

> 说明：release note 的“首次匹配版本”只代表**在已抓取 release 正文中第一次出现相关关键词**，不等于“官方精确首发版本”。
> 它更适合作为**版本线索**，不能单独替代官方 docs 总览页。

当前自动分析报告（抓取 114 个 release）得到的关键词线索如下：

| Feature | 首次匹配 release | 最新匹配 release | 解读 |
|---|---|---|---|
| XHTTP | `v1.8.16` | `v26.3.27` | 早期匹配主要来自 `SplitHTTP` / `XHTTP` 相关演进线索 |
| REALITY | `v1.7.5` | `v26.3.27` | release note 中很早就开始出现 REALITY 相关内容 |
| Hysteria | `v26.1.23` | `v26.3.27` | 当前抓到的 release 线索表明 Hysteria 功能是非常新的主线功能 |
| WireGuard | `v1.5.6` | `v26.3.27` | release note 中长期持续出现 |
| gRPC | `v1.4.0` | `v26.3.27` | 至今仍在 release note 中出现，不能据此认定已下架 |
| WebSocket | `v1.1.4` | `v26.3.27` | 至今仍在 release note 中出现，不能据此认定已下架 |
| HTTPUpgrade | `v1.8.9` | `v26.3.27` | 属较新的 transport 功能 |
| FinalMask | `v26.2.6` | `v26.3.27` | 非常新的附加配置功能 |
| Sockopt | `v1.4.0` | `v26.1.23` | 长期存在的附加配置功能 |

### 当前可以据此做出的保守结论

1. `WebSocket`、`gRPC` 到最新 release 仍有提及，**不能再写成 `v25+ 移除`**。
2. `Hysteria` 在当前抓取结果里首次显著出现于 `v26.1.23`，因此：
   - 它绝对不能再写成 `Never`；
   - 若后续要在 `V2rayU` 里做 Hysteria 硬版本门槛，`v26.1.23` 可以作为一个**候选起点线索**，但仍需再结合 docs / PR / 具体页面确认。
3. `WireGuard`、`REALITY`、`gRPC`、`WebSocket` 都具有明显的持续维护迹象。
4. `XHTTP` 的 release 线索可追溯到 `v1.8.16`（通过 `SplitHTTP/XHTTP` 关键词链路），但因为命名与功能边界经历过演化，`V2rayU` 当前仍保留较保守的版本阈值，不直接把首次匹配版本当作硬门槛。

---

## 3. 当前官方文档主列表：Inbound Protocols

以下功能是**当前官方入站协议总览页面明确列出的**：

| 功能 | 当前状态 | 来源 |
|---|---|---|
| Tunnel（dokodemo-door） inbound | 当前主列表支持 | `/config/inbounds/tunnel.html` |
| HTTP inbound | 当前主列表支持 | `/config/inbounds/http.html` |
| Shadowsocks inbound | 当前主列表支持 | `/config/inbounds/shadowsocks.html` |
| SOCKS inbound | 当前主列表支持 | `/config/inbounds/socks.html` |
| Trojan inbound | 当前主列表支持 | `/config/inbounds/trojan.html` |
| VLESS inbound | 当前主列表支持 | `/config/inbounds/vless.html` |
| VMess inbound | 当前主列表支持 | `/config/inbounds/vmess.html` |
| WireGuard inbound | 当前主列表支持 | `/config/inbounds/wireguard.html` |
| Hysteria inbound | 当前主列表支持 | `/config/inbounds/hysteria.html` |
| TUN inbound | 当前主列表支持 | `/config/inbounds/tun.html` |

### 修正点

此前文档中以下结论是错误的：

- `Hysteria inbound = Never` ❌
- `Hysteria2 inbound = Never` ❌（当前官方主列表至少明确有 `Hysteria`，但并没有单独叫 `Hysteria2` 的页面）
- `TUIC inbound = Never` 这个说法**不能从当前 Xray 官方主列表推出**；当前官方主列表也**没有 TUIC 页面**，因此不能再写成“官方明确 Never”，只能写成“当前主列表未列出”。

---

## 4. 当前官方文档主列表：Outbound Protocols

以下功能是**当前官方出站协议总览页面明确列出的**：

| 功能 | 当前状态 | 来源 |
|---|---|---|
| Blackhole outbound | 当前主列表支持 | `/config/outbounds/blackhole.html` |
| DNS outbound | 当前主列表支持 | `/config/outbounds/dns.html` |
| Freedom outbound | 当前主列表支持 | `/config/outbounds/freedom.html` |
| HTTP outbound | 当前主列表支持 | `/config/outbounds/http.html` |
| Loopback outbound | 当前主列表支持 | `/config/outbounds/loopback.html` |
| Shadowsocks outbound | 当前主列表支持 | `/config/outbounds/shadowsocks.html` |
| SOCKS outbound | 当前主列表支持 | `/config/outbounds/socks.html` |
| Trojan outbound | 当前主列表支持 | `/config/outbounds/trojan.html` |
| VLESS outbound | 当前主列表支持 | `/config/outbounds/vless.html` |
| VMess outbound | 当前主列表支持 | `/config/outbounds/vmess.html` |
| WireGuard outbound | 当前主列表支持 | `/config/outbounds/wireguard.html` |
| Hysteria outbound | 当前主列表支持 | `/config/outbounds/hysteria.html` |

### 修正点

此前文档中以下结论是错误的：

- `Hysteria outbound = Never` ❌
- `Hysteria2 outbound = Never` ❌（当前官方主列表并未单独叫 `Hysteria2`，不能直接据此写 Never）
- `TUIC outbound = Never` ❌（当前官方主列表未列出 TUIC，但这不等于可以直接写“Never”）

更准确的表述应当是：

- **当前主列表列出的功能**：可视为当前官方支持面
- **当前主列表未列出的功能**：只能写“当前主列表未列出 / 未单列”，不能直接写“Never”

---

## 5. 当前官方文档主列表：Transport / Security / Additional

### 5.1 Transport Methods

以下功能是**当前官方 transport 总览页面明确列出的**：

| 功能 | 当前状态 | 来源 |
|---|---|---|
| RAW | 当前主列表支持 | `/config/transports/raw.html` |
| XHTTP | 当前主列表支持 | `/config/transports/xhttp.html` |
| mKCP | 当前主列表支持 | `/config/transports/mkcp.html` |
| gRPC | 当前主列表支持 | `/config/transports/grpc.html` |
| WebSocket | 当前主列表支持 | `/config/transports/websocket.html` |
| HTTPUpgrade | 当前主列表支持 | `/config/transports/httpupgrade.html` |
| Hysteria transport | 当前主列表支持 | `/config/transports/hysteria.html` |

### 5.2 Transport Security

| 功能 | 当前状态 | 来源 |
|---|---|---|
| REALITY | 当前主列表支持 | `/config/transports/reality.html` |
| TLS | 当前主列表支持 | `/config/transports/tls.html` |

### 5.3 Additional Config

| 功能 | 当前状态 | 来源 |
|---|---|---|
| FinalMask | 当前主列表支持 | `/config/transports/finalmask.html` |
| Sockopt | 当前主列表支持 | `/config/transports/sockopt.html` |

### 修正点

此前文档中以下结论与当前官方文档冲突：

- `WebSocket = v25+ 移除` ❌（当前官方 transport 主列表仍明确列出）
- `gRPC = v25+ 移除` ❌（当前官方 transport 主列表仍明确列出）

因此，**V2rayU 不能再继续把 `ws/grpc` 默认视为“新版本 Xray 已不支持”**。

---

## 6. 历史/兼容功能：不在当前主列表，但站点仍保留页面或兼容痕迹

当前官方主列表**没有列出**以下 transport，但站点仍能看到历史页面或兼容内容：

| 功能 | 当前主列表 | 处理建议 |
|---|---|---|
| HTTP/2 (`h2`) | 不在当前主列表 | 按历史/兼容功能处理，不直接写“Never” |
| QUIC | 不在当前主列表 | 按历史/兼容功能处理，不直接写“Never” |
| 旧 `tcp` transport 名称 | 已被 `RAW` 取代 | 在客户端模型中应映射为 `RAW` |
| `domainsocket` | 当前主列表未单列 | 作为现有模型兼容项处理 |

也就是说：

- **不在当前主列表** ≠ **官方明确从未支持**
- **不在当前主列表** ≠ **一定已经从所有版本完全移除**

对这类功能，更合理的写法是：

- `历史页面仍存在`
- `当前主列表未列出`
- `V2rayU 按 legacy / compatibility 处理`

---

## 7. V2rayU 当前模型与官方 docs 的映射

### 7.1 `ProfileEntity.network` 映射

| V2rayU 模型值 | 对应官方概念 | 当前处理 |
|---|---|---|
| `tcp` | `RAW` | 作为 **RAW 别名** 处理 |
| `ws` | `WebSocket` | 视为当前官方主列表支持 |
| `grpc` | `gRPC` | 视为当前官方主列表支持 |
| `xhttp` | `XHTTP` | 视为当前官方主列表支持 |
| `kcp` | `mKCP` | 视为当前官方主列表支持 |
| `h2` | `HTTP/2` | 视为历史/兼容 transport |
| `quic` | `QUIC` | 视为历史/兼容 transport |
| `domainsocket` | Domain Socket | 视为现有模型兼容项 |

### 7.2 `ProfileEntity.security` 映射

| V2rayU 模型值 | 对应官方概念 | 当前处理 |
|---|---|---|
| `none` | 无额外 transport security | 隐含默认功能 |
| `tls` | `TLS` | 当前官方主列表支持 |
| `reality` | `REALITY` | 当前官方主列表支持 |
| `xtls` | 当前工程内暂按 TLS 兼容处理 | 不再在本文件里臆造版本范围 |

### 7.3 `flow`

当前 `xtls-rprx-vision*` 属于 `VLESS / XTLS / REALITY` 细分配置，**不在官方 transport 总览页单列**，所以本文件不再直接写死“>= 某版本”的结论；若后续要对 flow 做严格版本校验，应引用更具体的官方页面或 release note。

---

## 8. V2rayU 当前启动前校验：实际执行规则

### 8.1 当前会检查的内容

当前启动前仍会检查：

- outbound protocol
- transport
- stream security
- flow

### 8.2 当前**真正执行**的硬校验

目前只保留少量明确规则：

| 功能 | 当前校验策略 |
|---|---|
| `XHTTP` | 保留现有 `V2rayU` 兼容阈值：旧语义版本 `>= 1.8.24`，日期版本 `>= 24.9.30`；不满足则回退 `Sing-Box` |
| `ws` / `grpc` | **不再**因为“文档误判为已下架”而自动回退 `Sing-Box` |
| `h2` | 作为历史/兼容 transport，只做提示，不再直接依据错误文档强制判死 |

### 8.3 当前只做提示、不强制切核心的内容

当前功能支持规则中的 `rule.type` 按状态分为：

- `supported`：当前主线支持功能；如已知起始版本 / 移除版本，直接写在同一条规则里
- `legacy`：历史兼容项，不再属于当前主线支持面，但仍保留兼容说明；也可以附带版本边界
- `compatibility`：别名 / 默认项 / 映射兼容项，用于表达客户端兼容语义；必要时也可附带版本边界
- `removed`：已明确移除的功能；若知道移除版本，应写入 `removedAt`
- `pendingReview`：证据还不完整，暂不把它归入 supported / legacy / removed 中任一类

也就是说，**版本边界不是一种状态**：

- 起始版本由 `legacyMin` / `calendarMin` 表达
- 移除版本由 `removedAt` 表达
- `rule.type` 只表达“它现在属于哪种状态”

- `h2`
- `quic`
- `legacy` / `compatibility` 类型功能

这些项会提示“当前官方主列表未列出 / 作为历史兼容或客户端兼容处理”，但**不会仅凭这一点就自动切 core**。

---

## 9. 当前文档结论

### 可以明确写“当前官方支持”的

以当前官方 docs 主列表为准，可明确写支持的包括：

- Inbound：`Tunnel`、`HTTP`、`Shadowsocks`、`SOCKS`、`Trojan`、`VLESS`、`VMess`、`WireGuard`、`Hysteria`、`TUN`
- Outbound：`Blackhole`、`DNS`、`Freedom`、`HTTP`、`Loopback`、`Shadowsocks`、`SOCKS`、`Trojan`、`VLESS`、`VMess`、`WireGuard`、`Hysteria`
- Transport：`RAW`、`XHTTP`、`mKCP`、`gRPC`、`WebSocket`、`HTTPUpgrade`、`Hysteria`
- Security：`REALITY`、`TLS`
- Additional：`FinalMask`、`Sockopt`

### 不能再直接写死的

以下说法不应再直接写入功能支持规则：

- `Hysteria = Never`
- `WireGuard = 不支持`
- `WebSocket = v25+ 移除`
- `gRPC = v25+ 移除`
- 任何没有来源支撑的 `>= 1.0.0`
- 任何仅凭“当前 sidebar 没出现”就写成 `Never`

---

## 10. 维护原则

后续维护必须遵守：

1. **支持面**优先以当前官方 docs 总览页为准
2. **版本边界**只有在有明确来源时才写死
   - 官方 release note
   - 官方 docs 明示
   - 工程内已有可靠兼容规则且能说明来源
3. 对于 `legacy` / `compatibility` / `removed` / `pendingReview` 项：
   - 必须明确说明它为什么不是当前主线 `supported`
   - `legacy` / `compatibility` 只能写“历史兼容 / 客户端兼容”，不要冒充当前主线支持
   - 若写“已移除”，必须尽量给出 `removedAt` 或对应 evidence
   - 若写 `pendingReview`，必须说明当前缺的证据是什么
   - 不要直接写没有来源支撑的 “Never” / “已彻底移除”
4. 若 `V2rayU` 新增 `Hysteria / WireGuard / TUIC` 等节点模型，需同步更新：
   - `Core/Utilities/CoreCapabilityRules.swift`
   - 本文档
   - `Docs/XrayReleaseFeatureAnalysis.md`
   - 运行时 `resolveCoreCompatibility()` 的映射规则
