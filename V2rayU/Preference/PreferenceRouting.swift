//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceRoutingViewController: NSViewController, PreferencePane {

    let preferencePaneIdentifier = PreferencePane.Identifier.routingTab
    let preferencePaneTitle = "Routing"
    let toolbarItemIcon = NSImage(named: NSImage.networkName)!

    @IBOutlet weak var domainStrategy: NSPopUpButton!
    @IBOutlet weak var routingRule: NSPopUpButton!
    @IBOutlet var proxyTextView: NSTextView!
    @IBOutlet var directTextView: NSTextView!
    @IBOutlet var blockTextView: NSTextView!

    override var nibName: NSNib.Name? {
        return "PreferenceRouting"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);

        let domainStrategy = UserDefaults.get(forKey: .routingDomainStrategy) ?? "AsIs"
        self.domainStrategy.selectItem(withTitle: domainStrategy)

        let routingRule = Int(UserDefaults.get(forKey: .routingRule) ?? "0") ?? 0
        self.routingRule.selectItem(withTag: routingRule)

        let routingProxyDomains = UserDefaults.getArray(forKey: .routingProxyDomains) ?? [];
        let routingProxyIps = UserDefaults.getArray(forKey: .routingProxyIps) ?? [];
        let routingDirectDomains = UserDefaults.getArray(forKey: .routingDirectDomains) ?? [];
        let routingDirectIps = UserDefaults.getArray(forKey: .routingDirectIps) ?? [];
        let routingBlockDomains = UserDefaults.getArray(forKey: .routingBlockDomains) ?? [];
        let routingBlockIps = UserDefaults.getArray(forKey: .routingBlockIps) ?? [];

        let routingProxy = routingProxyDomains + routingProxyIps
        let routingDirect = routingDirectDomains + routingDirectIps
        let routingBlock = routingBlockDomains + routingBlockIps

        print("routingProxy", routingProxy, routingDirect, routingBlock)
        self.proxyTextView.string = routingProxy.joined(separator: "\n")
        self.directTextView.string = routingDirect.joined(separator: "\n")
        self.blockTextView.string = routingBlock.joined(separator: "\n")
    }

    @IBAction func goHelp(_ sender: Any) {
        guard let url = URL(string: "https://toutyrater.github.io/basic/routing/") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goHelp2(_ sender: Any) {
        guard let url = URL(string: "https://github.com/v2ray/domain-list-community") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func saveRouting(_ sender: Any) {
        UserDefaults.set(forKey: .routingDomainStrategy, value: self.domainStrategy.titleOfSelectedItem!)
        UserDefaults.set(forKey: .routingRule, value: String(self.routingRule.selectedTag()))

        var (domains, ips) = self.parseDomainOrIp(domainIpStr: self.proxyTextView.string)
        UserDefaults.setArray(forKey: .routingProxyDomains, value: domains)
        UserDefaults.setArray(forKey: .routingProxyIps, value: ips)

        (domains, ips) = self.parseDomainOrIp(domainIpStr: self.directTextView.string)
        UserDefaults.setArray(forKey: .routingDirectDomains, value: domains)
        UserDefaults.setArray(forKey: .routingDirectIps, value: ips)

        (domains, ips) = self.parseDomainOrIp(domainIpStr: self.blockTextView.string)
        UserDefaults.setArray(forKey: .routingBlockDomains, value: domains)
        UserDefaults.setArray(forKey: .routingBlockIps, value: ips)

        makeToast(message: "v2ray: routing rule setting success", displayDuration: 1)

        // set current server item and reload v2ray-core
        regenerateAllConfig()
    }

    func parseDomainOrIp(domainIpStr: String) -> (domains: [String], ips: [String]) {
        let all = domainIpStr.split(separator: "\n")

        var domains: [String] = []
        var ips: [String] = []

        for item in all {
            let tmp = item.trimmingCharacters(in: .whitespacesAndNewlines)

            // is ip
            if isIp(str: tmp) || tmp.contains("geoip:") {
                ips.append(tmp)
                continue
            }

            // is domain
            if tmp.contains("domain:") || tmp.contains("geosite:") {
                domains.append(tmp)
                continue
            }

            if isDomain(str: tmp) {
                domains.append(tmp)
                continue
            }
        }

        print("ips", ips, "domains", domains)

        return (domains, ips)
    }

    func isIp(str: String) -> Bool {
        let pattern = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/[0-9]{2})?$"
        if ((str.count == 0) || (str.range(of: pattern, options: .regularExpression) == nil)) {
            return false
        }
        return true
    }

    func isDomain(str: String) -> Bool {
        let pattern = "[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+"
        if ((str.count == 0) || (str.range(of: pattern, options: .regularExpression) == nil)) {
            return false
        }
        return true
    }
}
