# V2rayU 跨版本兼容性测试系统设计

## 1. 概述

本系统旨在解决 Xray-core 和 sing-box 的多个历史版本与用户配置的兼容性问题。通过自动化测试覆盖所有显著变更的版本，确保 V2rayU 生成的配置能在对应核心版本上正常运行。

### 解决的问题

1. **版本碎片化**：用户可能使用任意版本的核心二进制，兼容规则需要验证
2. **配置生成一致性**：同一个 profile 配置在不同核心版本上生成的 JSON 是否有效
3. **功能差异追踪**：不同版本之间协议、传输方式的支持变化
4. **兼容规则验证**：当前 `CoreCapabilityRules` 中的版本边界定义是否准确

## 2. 版本覆盖范围

### Xray-core

从 `v1.8.0` 到 `v26.5.6`，包含所有稳定版（非 draft、非 prerelease）。

版本线分为两个阶段：
- **旧语义版本**：v1.8.0 ~ v1.8.24（major=1 系列）
- **日历版本**：v24.9.30 ~ v26.5.6（major>=24 系列）

### sing-box

从 `v1.12.0` 到 `v1.13.12`，包含所有稳定版。

## 3. 系统架构

```
┌──────────────────────────────────────────────────────────┐
│                    download-cores.sh                      │
│  GitHub Releases API → 下载 → 解压 → 命名 → 存储         │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
         Build/tests/bin/
    ┌──────────┴──────────┐
    ▼                     ▼
 xray-core/           sing-box/
  v1.8.0/              v1.12.0/
  v1.8.1/              v1.12.1/
  ...                  ...
  v26.5.6/             v1.13.12/

               │
               ▼
┌──────────────────────────────────────────────────────────┐
│              run-compatibility-test.sh                    │
│  1. xcodebuild test (V2rayUTests 目标)                    │
│  2. 收集测试结果                                          │
│  3. 生成 HTML/JSON 报告                                   │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│        V2rayUCompatibilityTest (Swift Testing)            │
│                                                           │
│  对于每个 profile × (coreType, coreVersion) 组合:          │
│  1. 检查能力规则预测的结果                                  │
│  2. 使用测试版核心二进制生成配置并启动                       │
│  3. 测试真实连通性                                         │
│  4. 记录结果到 JSON 报告                                   │
└──────────────────────────────────────────────────────────┘
```

## 4. 核心组件设计

### 4.1 CoreDownloader — 核心下载器

**位置**：`Build/tests/download-cores.sh`

**功能**：
- 通过 GitHub Releases API 获取指定 repo 的发布列表
- 过滤出稳定版（!draft && !prerelease）
- 匹配版本范围
- 下载对应平台的二进制包（arm64 优先）
- 解压并重命名为统一格式
- 存储到 `Build/tests/bin/{core}/{version_tag}/binary`

**版本过滤规则**：

| 核心 | 最低版本 | 最高版本 | 版本格式 |
|------|---------|---------|---------|
| Xray-core | v1.8.0 | v26.5.6 | `v{major}.{minor}.{patch}` |
| sing-box | v1.12.0 | v1.13.12 | `v{major}.{minor}.{patch}` |

**下载目录结构**：
```
Build/tests/bin/
├── xray-core/
│   ├── v1.8.0/
│   │   └── xray-arm64    # 解压后的可执行文件
│   ├── v1.8.1/
│   └── ...
└── sing-box/
    ├── v1.12.0/
    │   └── sing-box-arm64
    └── ...
```

### 4.2 CompatibilityTestRunner — 测试运行器

**位置**：`V2rayUTests/CompatibilityTestRunner.swift`

**功能**：
- 从 Store 读取所有 profile 配置
- 枚举待测的核心版本列表
- 对每个 (profile, core_version) 组合：
  1. **能力检查**：使用 `XraySupportCatalog` / `SingboxFallbackResolver` 预判是否兼容
  2. **配置生成**：通过 `CoreConfigHandler.toJSON()` 生成 JSON 配置
  3. **核心启动**：使用测试目录下的对应版本二进制启动
  4. **连通测试**：通过代理端口或核心 API 测试延迟
  5. **结果记录**：记录成功/失败/不兼容等信息

#### 核心路径覆盖机制

测试时需要覆盖 `getCoreFile(mode:)` 返回的路径。通过环境的 `V2RAYU_TEST_CORE_DIR` 或参数来实现：

```swift
func testCoreBinaryPath(version: String, mode: CoreType) -> String {
    let base = ProcessInfo.processInfo.environment["V2RAYU_TEST_BIN_DIR"]
        ?? "\(projectRoot)/Build/tests/bin"
    let subDir = mode == .XrayCore ? "xray-core" : "sing-box"
    #if arch(arm64)
    let binary = mode == .XrayCore ? "xray-arm64" : "sing-box-arm64"
    #else
    let binary = mode == .XrayCore ? "xray-64" : "sing-box-64"
    #endif
    return "\(base)/\(subDir)/\(version)/\(binary)"
}
```

### 4.3 TestReport — 报告生成器

**格式**：JSON + HTML 摘要

**JSON 报告结构**：
```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-06-06T12:00:00Z",
  "environment": {
    "arch": "arm64",
    "osVersion": "macOS 15.x"
  },
  "coreVersions": {
    "xray": ["v1.8.0", "v1.8.1", ..., "v26.5.6"],
    "singbox": ["v1.12.0", ..., "v1.13.12"]
  },
  "profiles": [
    {
      "uuid": "...",
      "remark": "my-server",
      "protocol": "vmess",
      "network": "tcp",
      "security": "tls",
      "coreType": "auto"
    }
  ],
  "results": [
    {
      "profileUUID": "...",
      "coreType": "xray",
      "coreVersion": "v1.8.0",
      "rulePrediction": "supported",
      "configGenerated": true,
      "connectionTest": {
        "succeeded": true,
        "latencyMs": 123,
        "error": null
      },
      "ruleMatched": true
    }
  ],
  "summary": {
    "totalCombinations": 1000,
    "succeeded": 800,
    "failed": 100,
    "incompatible": 100,
    "ruleMismatches": [
      {
        "profileUUID": "...",
        "coreType": "xray",
        "coreVersion": "v1.8.0",
        "rulePredicted": "supported",
        "actualResult": "failed",
        "likelyRootCause": "protocol not supported in this version"
      }
    ]
  }
}
```

## 5. 测试流程

### 5.1 单次测试流程（per profile × version）

```
对于每个 profile:
  对于 xray 版本列表:
    1. 检查能力规则
       - 如果规则标记为 unsupported/removed → 跳过测试，记录兼容
       - 如果规则标记为 supported/legacy → 继续
    2. 设置核心路径为测试版本
    3. 生成 JSON 配置 (CoreConfigHandler.toJSON)
    4. 启动核心进程
    5. 等待端口就绪 (timeout: 5s)
    6. 测试连通性（通过 HTTP 代理端口 send GET → 检查 204）
    7. 记录延迟/错误
    8. 终止核心进程，清理临时文件
    9. 对比规则预测 vs 实际结果
    
  对于 sing-box 版本列表:
    类似流程，使用 SingBoxConfigHandler
```

### 5.2 完整运行流程

```bash
# Phase 1: 下载所有核心版本
./Build/tests/download-cores.sh

# Phase 2: 运行兼容性测试
./Build/tests/run-compatibility-test.sh

# Phase 3: 查看报告
open Build/tests/reports/latest/summary.html
```

## 6. 文件清单

### 新增文件

| 文件 | 类型 | 说明 |
|------|------|------|
| `Build/tests/download-cores.sh` | Shell | 下载所有需要测试的核心二进制 |
| `Build/tests/run-compatibility-test.sh` | Shell | 运行完整测试套件 |
| `V2rayUTests/CompatibilityTestRunner.swift` | Swift | 测试主逻辑 |
| `V2rayUTests/CompatibilityTestModels.swift` | Swift | 测试数据模型和报告结构 |
| `Build/tests/reports/` | 目录 | 报告输出目录 (gitignored) |

### 修改文件

| 文件 | 变更说明 |
|------|---------|
| `.gitignore` | 添加 `Build/tests/bin/` 和 `Build/tests/reports/` |

## 7. 实现计划

### Phase 1: 下载脚本
- [x] `download-cores.sh` 实现
  - GitHub API 分页获取 release 列表
  - 版本过滤和范围匹配
  - 架构匹配下载
  - 解压和命名规范

### Phase 2: 测试基础设施
- [ ] `CompatibilityTestModels.swift` — 测试数据模型
- [ ] `CompatibilityTestRunner.swift` — 测试执行器
  - Profile 遍历
  - 核心版本枚举
  - 能力规则预检查
  - 配置生成
  - 进程启动/管理
  - 连通性测试
  - 结果收集

### Phase 3: 报告与分析
- [ ] JSON 报告输出
- [ ] 规则准确性对比分析
- [ ] HTML 摘要报告

## 8. 注意事项

1. **安全性**：测试会启动真实核心进程，确保使用随机端口避免冲突
2. **性能**：大量版本 × 大量 profile 会产生大量组合，需要合理设置并发度
3. **磁盘空间**：多个核心版本会占用较多磁盘空间（每个 xray ~50MB）
4. **网络依赖**：GitHub API 有频率限制，下载需要稳定的网络连接
5. **DB 访问**：测试工具需要只读访问用户数据库，不应修改生产数据
6. **测试版核心**：仅在测试时覆盖核心路径，不应影响生产环境的核心管理
