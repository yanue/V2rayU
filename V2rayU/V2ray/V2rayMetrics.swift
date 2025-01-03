//
//  V2rayMetrics.swift
//  V2rayU
//
//  Created by yanue on 2025/1/3.
//

import Cocoa

// go的exportVars: http://127.0.0.1:11111/debug/vars

// MARK: - V2rayMetricsVars
struct V2rayMetricsVars: Codable {
    var observatory: [String: V2rayMetricObservatory]?
    var stats: V2rayMetricStats?
}

struct V2rayMetricObservatory: Codable {
    var alive: Bool
    var delay: Int
    var outbound_tag: String
    var last_seen_time: Int
}

struct V2rayMetricStats: Codable {
    var inbound: [String: V2rayMetricsVarsLink] // socks_inbound: { "downlink": 0, "uplink": 0 }
    var outbound: [String: V2rayMetricsVarsLink] // "api": { "downlink": 0, "uplink": 0 }
}

struct V2rayMetricsVarsLink: Codable {
    var downlink: Int
    var uplink: Int
}
