#!/usr/bin/env python3
"""生成规则准确性对比分析 HTML 报告"""

import json
import sqlite3
import os
import sys
from datetime import datetime
from collections import defaultdict, Counter

def load_report(path):
    with open(path) as f:
        return json.load(f)

def get_profiles(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.execute("SELECT uuid, remark, protocol, network, alterId, address, port FROM profile")
    profiles = {}
    for row in cur:
        profiles[row['uuid']] = dict(row)
    conn.close()
    return profiles

def classify_mismatch(result):
    """Classify what type of mismatch/result this is"""
    status = result['connection']['status']
    prediction = result['connection'].get('rulePrediction', 'unknown')
    core = result['coreTypeRaw']
    ver = result['coreVersion']
    proto = result['protocolRaw']
    network = result['networkRaw']

    if status == 'pass':
        if prediction in ('supported', 'advisory'):
            return 'correct_pass'
        else:
            return 'unexpected_pass'
    elif status == 'skipped':
        if prediction == 'unsupported':
            return 'correct_skip'
        else:
            return 'unexpected_skip'
    elif status == 'fail':
        if prediction == 'unsupported':
            return 'correct_fail'
        else:
            return 'unexpected_fail'
    elif status == 'timeout':
        if prediction == 'unsupported':
            return 'correct_timeout'
        else:
            return 'unexpected_timeout'
    return 'unknown'

def generate_html(report, profiles):
    results = report['results']
    summary = report.get('summary', {})
    mismatches = report.get('ruleMismatches', [])

    # Classify all results
    classified = defaultdict(list)
    for r in results:
        cat = classify_mismatch(r)
        classified[cat].append(r)

    # Profile-level breakdown
    profile_stats = defaultdict(lambda: {
        'remark': '', 'protocol': '', 'network': '',
        'total': 0, 'pass': 0, 'fail': 0, 'timeout': 0, 'skipped': 0,
        'correct': 0, 'mismatch': 0,
        'XrayCore': {'pass': 0, 'fail': 0, 'timeout': 0, 'skipped': 0},
        'SingBox': {'pass': 0, 'fail': 0, 'timeout': 0, 'skipped': 0},
        'by_version': []
    })

    for r in results:
        puid = r['profileUUID']
        remark = r['profileRemark']
        p = profile_stats[puid]
        p['remark'] = remark
        p['protocol'] = r['protocolRaw']
        p['network'] = r['networkRaw']
        p['total'] += 1
        s = r['connection']['status']
        p[s] += 1
        core = r['coreTypeRaw']
        p[core][s] += 1
        cat = classify_mismatch(r)
        if cat.startswith('correct'):
            p['correct'] += 1
        else:
            p['mismatch'] += 1

    # Version-level timeout/fail analysis
    timeout_by_profile = defaultdict(lambda: defaultdict(list))
    fail_by_profile = defaultdict(lambda: defaultdict(list))
    for r in results:
        if r['connection']['status'] in ('timeout', 'fail'):
            key = f"{r['profileRemark']} / {r['coreTypeRaw']}"
            timeout_by_profile[key][r['coreVersion']].append(r)

    # Build HTML
    from html import escape

    total = len(results)
    passes = len(classified.get('correct_pass', [])) + len(classified.get('unexpected_pass', []))
    correct = len([r for r in results if classify_mismatch(r).startswith('correct')])
    mismatch = total - correct

    # Generate version matrix data
    core_versions = sorted(set(r['coreVersion'] for r in results),
                          key=lambda v: [int(x) for x in v.lstrip('v').split('.')[:3]])

    profile_names = []
    seen = set()
    for r in results:
        key = (r['profileRemark'], r['coreTypeRaw'])
        if key not in seen:
            profile_names.append(key)
            seen.add(key)

    def status_char(r):
        s = r['connection']['status']
        cat = classify_mismatch(r)
        pred = r['connection'].get('rulePrediction', '?')
        if s == 'pass': return 'P'
        if s == 'skipped': return 'S'
        if s == 'fail': return 'F'
        if s == 'timeout': return 'T'
        return '?'

    def cell_color(r):
        s = r['connection']['status']
        cat = classify_mismatch(r)
        if cat.startswith('correct'):
            if s == 'pass': return '#e6ffe6'
            if s == 'skipped': return '#f0f0f0'
            if s == 'fail': return '#fff0f0'
            if s == 'timeout': return '#fffff0'
        else:
            if s == 'pass': return '#ffe6f0'
            if s == 'timeout': return '#ffe0e0'
            if s == 'fail': return '#ffcccc'
            if s == 'skipped': return '#ffe0e0'
        return '#ffffff'

    def lat_text(r):
        lat = r['connection'].get('latencyMs')
        if lat and lat > 0:
            return f"{lat:.0f}ms"
        return r['connection']['status']

    # Build result lookup: (uuid, coreType, version) -> result
    lookup = {}
    for r in results:
        lookup[(r['profileUUID'], r['coreTypeRaw'], r['coreVersion'])] = r

    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    html = f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>规则准确性对比分析</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 20px; background: #f8f9fa; color: #333; }}
h1, h2, h3 {{ color: #1a1a2e; }}
.summary {{ display: flex; gap: 15px; flex-wrap: wrap; margin: 15px 0; }}
.card {{ background: white; border-radius: 8px; padding: 15px 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); flex: 1; min-width: 140px; }}
.card .num {{ font-size: 28px; font-weight: 700; }}
.card .label {{ font-size: 12px; color: #666; text-transform: uppercase; }}
.card.green .num {{ color: #28a745; }}
.card.red .num {{ color: #dc3545; }}
.card.orange .num {{ color: #fd7e14; }}
.card.blue .num {{ color: #007bff; }}
.card.gray .num {{ color: #6c757d; }}
table {{ border-collapse: collapse; font-size: 12px; margin: 10px 0; }}
th, td {{ border: 1px solid #ddd; padding: 4px 6px; text-align: center; }}
th {{ background: #f1f3f5; position: sticky; top: 0; z-index: 10; }}
tr:hover {{ background: #f8f9ff; }}
.profile-col {{ text-align: left; white-space: nowrap; min-width: 140px; }}
.correct {{ background: #e6ffe6; }}
.mismatch {{ background: #ffe6e6; }}
.legend {{ margin: 10px 0; font-size: 12px; }}
.legend span {{ margin-right: 15px; }}
.detail-section {{ margin: 20px 0; }}
.detail-table {{ width: 100%; }}
.cell-P {{ background: #d4edda; }}
.cell-F {{ background: #f8d7da; }}
.cell-T {{ background: #fff3cd; }}
.cell-S {{ background: #e2e3e5; }}
.sort-control {{ margin: 10px 0; }}
.filter-btn {{ padding: 4px 12px; margin: 0 4px; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; background: white; }}
.filter-btn.active {{ background: #007bff; color: white; border-color: #007bff; }}
.tooltip {{ position: relative; cursor: help; }}
.tooltip:hover .tooltip-text {{ display: block; }}
.tooltip-text {{ display: none; position: absolute; background: #333; color: white; padding: 8px 12px; border-radius: 4px; font-size: 11px; z-index: 100; max-width: 400px; bottom: 100%; left: 50%; transform: translateX(-50%); white-space: normal; }}
.mismatch-detail {{ margin: 5px 0; padding: 8px; border-radius: 4px; font-size: 12px; }}
.mismatch-detail.timeout {{ background: #fff3cd; }}
.mismatch-detail.fail {{ background: #f8d7da; }}
.mismatch-detail.pass {{ background: #d4edda; }}
.mismatch-detail.skipped {{ background: #e2e3e5; }}
</style>
</head>
<body>
<h1>规则准确性对比分析</h1>
<p>生成时间: {now} | 报告: {os.path.basename(report_path)}</p>

<div class="summary">
  <div class="card blue">
    <div class="num">{total}</div>
    <div class="label">总测试组合</div>
  </div>
  <div class="card green">
    <div class="num">{passes}</div>
    <div class="label">通过</div>
  </div>
  <div class="card orange">
    <div class="num">{len(classified.get('correct_fail',[])) + len(classified.get('correct_timeout',[])) + len(classified.get('correct_skip',[]))}</div>
    <div class="label">正确阻断/跳过</div>
  </div>
  <div class="card green">
    <div class="num">{correct}</div>
    <div class="label">规则正确</div>
  </div>
  <div class="card red">
    <div class="num">{mismatch}</div>
    <div class="label">规则偏差</div>
  </div>
  <div class="card gray">
    <div class="num">{len(classified.get('unexpected_fail',[])) + len(classified.get('unexpected_timeout',[]))}</div>
    <div class="label">意外阻断</div>
  </div>
</div>

<h2>偏差明细</h2>
<table>
<tr>
  <th>类型</th><th>数量</th><th>占比</th><th>说明</th>
</tr>
<tr class="mismatch">
  <td>unexpected_pass</td>
  <td>{len(classified.get('unexpected_pass',[]))}</td>
  <td>{len(classified.get('unexpected_pass',[]))/total*100:.1f}%</td>
  <td>预测为unsupported但实际通过 — 规则过于严格</td>
</tr>
<tr class="mismatch">
  <td>unexpected_timeout</td>
  <td>{len(classified.get('unexpected_timeout',[]))}</td>
  <td>{len(classified.get('unexpected_timeout',[]))/total*100:.1f}%</td>
  <td>预测为supported/advisory但端口未就绪 — 核心/配置问题</td>
</tr>
<tr class="mismatch">
  <td>unexpected_fail</td>
  <td>{len(classified.get('unexpected_fail',[]))}</td>
  <td>{len(classified.get('unexpected_fail',[]))/total*100:.1f}%</td>
  <td>预测为supported/advisory但连接失败 — 核心/服务器问题</td>
</tr>
<tr class="mismatch">
  <td>unexpected_skip</td>
  <td>{len(classified.get('unexpected_skip',[]))}</td>
  <td>{len(classified.get('unexpected_skip',[]))/total*100:.1f}%</td>
  <td>预测为unsupported但实际测试跳过 — 是否需要放宽规则</td>
</tr>
</table>

<h2>各Profile统计</h2>
<table>
<tr>
  <th>Profile</th><th>协议/网络</th><th>总计</th><th>通过</th><th>失败</th><th>超时</th><th>跳过</th>
  <th>规则正确</th><th>规则偏差</th><th>Xray 通过</th><th>Xray 失败</th><th>Xray 超时</th><th>SingBox 通过</th><th>SingBox 失败</th><th>SingBox 超时</th>
</tr>
'''
    for puid, p in sorted(profile_stats.items(), key=lambda x: x[1]['remark']):
        acc = p['correct'] / p['total'] * 100 if p['total'] else 0
        html += f'''<tr>
  <td class="profile-col">{escape(p['remark'])}</td>
  <td>{escape(p['protocol'])}/{escape(p['network'])}</td>
  <td>{p['total']}</td>
  <td>{p['pass']}</td>
  <td>{p['fail']}</td>
  <td>{p['timeout']}</td>
  <td>{p['skipped']}</td>
  <td class="correct">{p['correct']} ({acc:.0f}%)</td>
  <td class="mismatch">{p['mismatch']}</td>
  <td>{p['XrayCore']['pass']}</td>
  <td>{p['XrayCore']['fail']}</td>
  <td>{p['XrayCore']['timeout']}</td>
  <td>{p['SingBox']['pass']}</td>
  <td>{p['SingBox']['fail']}</td>
  <td>{p['SingBox']['timeout']}</td>
</tr>
'''

    html += '''</table>

<h2>版本兼容矩阵</h2>
<p>P=通过 F=连接失败 T=超时(端口未就绪) S=跳过 | 颜色: <span style="background:#d4edda">通过</span> <span style="background:#f8d7da">失败</span> <span style="background:#fff3cd">超时</span> <span style="background:#e2e3e5">跳过</span> | <b>红字=规则偏差</b></p>

<div style="overflow-x: auto; max-height: 800px; overflow-y: auto;">
<table>
<tr>
  <th style="position: sticky; left: 0; z-index: 20; background: #f1f3f5;">Profile / Core</th>
'''

    for ver in core_versions:
        html += f'<th>{ver}</th>'
    html += '</tr>\n'

    for remark, core_type in profile_names:
        html += f'<tr><td class="profile-col" style="position: sticky; left: 0; background: white; z-index: 5;">{escape(remark)}<br><small>{core_type}</small></td>'
        for ver in core_versions:
            r = lookup.get((None, core_type, ver))
            # Find matching result
            for puid in profile_stats:
                if profile_stats[puid]['remark'] == remark:
                    r = lookup.get((puid, core_type, ver))
                    break
            if r:
                cat = classify_mismatch(r)
                is_mismatch = not cat.startswith('correct')
                style = cell_color(r)
                char = status_char(r)
                extra = ' font-weight: bold; color: red;' if is_mismatch else ''
                title = f"{r['connection'].get('error','')} | pred={r['connection'].get('rulePrediction','?')}"
                html += f'<td style="background:{style};{extra}" title="{escape(title)}">{char}</td>'
            else:
                html += '<td>-</td>'
        html += '</tr>\n'

    html += '''</table>
</div>

<h2>意外超时明细 (unexpected_timeout)</h2>
<p>这些组合预测为supported/advisory但核心端口未就绪，需要分析根因</p>
<table>
<tr><th>Profile</th><th>Core</th><th>版本</th><th>预测</th><th>协议</th><th>网络</th></tr>
'''
    for r in sorted(classified.get('unexpected_timeout', []), key=lambda x: (x['profileRemark'], x['coreVersion'])):
        html += f'''<tr class="mismatch">
  <td>{escape(r['profileRemark'])}</td>
  <td>{r['coreTypeRaw']}</td>
  <td>{r['coreVersion']}</td>
  <td>{r['connection'].get('rulePrediction','?')}</td>
  <td>{r['protocolRaw']}</td>
  <td>{r['networkRaw']}</td>
</tr>
'''

    html += '''</table>

<h2>意外失败明细 (unexpected_fail)</h2>
<table>
<tr><th>Profile</th><th>Core</th><th>版本</th><th>预测</th><th>协议</th><th>网络</th></tr>
'''
    for r in sorted(classified.get('unexpected_fail', []), key=lambda x: (x['profileRemark'], x['coreVersion'])):
        html += f'''<tr class="mismatch">
  <td>{escape(r['profileRemark'])}</td>
  <td>{r['coreTypeRaw']}</td>
  <td>{r['coreVersion']}</td>
  <td>{r['connection'].get('rulePrediction','?')}</td>
  <td>{r['protocolRaw']}</td>
  <td>{r['networkRaw']}</td>
</tr>
'''

    html += '''</table>

<h2>规则偏差汇总 (ruleMismatches from report)</h2>
<table>
<tr><th>Profile</th><th>Core</th><th>版本</th><th>状态</th><th>预测</th><th>错误</th></tr>
'''
    for m in mismatches:
        html += f'''<tr class="mismatch">
  <td>{escape(m.get('profileRemark', ''))}</td>
  <td>{m.get('coreType', '')}</td>
  <td>{m.get('coreVersion', '')}</td>
  <td>{m.get('actualStatus', '')}</td>
  <td>{m.get('rulePredicted', '')}</td>
  <td style="font-size:11px;max-width:300px;word-break:break-all;">{escape(m.get('error', ''))}</td>
</tr>
'''

    html += '''
</table>

<h2>规则更新建议</h2>
<table>
<tr><th>规则</th><th>当前状态</th><th>建议</th><th>依据</th></tr>
<tr>
  <td>transport.h2</td>
  <td>已更新: supported(removedAt: 24.12.18)</td>
  <td>✅ 已修复</td>
  <td>xray v24.12.18 明确报错 "HTTP transport has been removed"</td>
</tr>
<tr>
  <td>transport.hysteria</td>
  <td>已更新: supported(calendarMin: 26.1.23)</td>
  <td>✅ 已修复</td>
  <td>xray v25.12.8 报错 "unknown transport protocol: hysteria"; v26.1.23 正常启动</td>
</tr>
<tr>
  <td>outbound.hysteria</td>
  <td>已更新: supported(calendarMin: 26.1.23)</td>
  <td>✅ 已修复</td>
  <td>同上，hysteria2 protocol 和 transport 同时添加</td>
</tr>
</table>

<p>生成脚本: Build/tests/generate-report.py</p>
</body>
</html>'''

    return html

if __name__ == '__main__':
    if len(sys.argv) > 1:
        report_path = sys.argv[1]
    else:
        report_path = '/Users/yanue/swift/V2rayU/Build/tests/reports/compatibility-report-2026-06-07_165331.json'

    db_path = '/Users/yanue/.V2rayU/.V2rayU.db'

    report = load_report(report_path)
    profiles = get_profiles(db_path)
    html = generate_html(report, profiles)

    out_path = report_path.replace('.json', '.html')
    with open(out_path, 'w') as f:
        f.write(html)
    print(f"HTML report written to: {out_path}")
    print(f"Total results: {len(report['results'])}")
    print(f"Mismatches count: {len(report.get('ruleMismatches', []))}")
    print(f"Summary: {json.dumps(report.get('summary', {}))}")
