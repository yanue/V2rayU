//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceRoutingViewController: NSViewController, PreferencePane, NSTabViewDelegate {

    let preferencePaneIdentifier = PreferencePane.Identifier.routingTab
    let preferencePaneTitle = "Routing"
    let toolbarItemIcon = NSImage(named: NSImage.networkName)!
    let tableViewDragType: String = "v2ray.routing"

    @IBOutlet weak var domainStrategy: NSPopUpButton!
    @IBOutlet weak var routingRule: NSPopUpButton!
    @IBOutlet var proxyTextView: NSTextView!
    @IBOutlet var directTextView: NSTextView!
    @IBOutlet var blockTextView: NSTextView!
    @IBOutlet weak var routingRuleContent: NSTextView!
    @IBOutlet weak var routingRuleName: NSTextField!
    @IBOutlet weak var errTip: NSTextField!
    @IBOutlet weak var routingsTableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!
    
    let default_rule_content =  """
{
    "domainStrategy": "AsIs",
    "rules": [
    ]
}
"""
    
    override var nibName: NSNib.Name? {
        return "PreferenceRouting"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
        // set table drag style
        self.routingsTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
        self.routingsTableView.allowsMultipleSelection = true

        // reload tableview
        V2rayRoutings.loadConfig()
        // table view
        self.routingsTableView.delegate = self
        self.routingsTableView.dataSource = self
        self.routingsTableView.reloadData()
        
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
    
    @IBAction func saveManualRouting(_ sender: Any) {
        print("saveManualRouting")
        
        let routingRuleContent = self.routingRuleContent?.string
        guard let routingRuleName = self.routingRuleName?.stringValue else {
            self.set_tip(str: "missing custom routing rule name")
            return
        }
        guard let routingRuleContent = self.routingRuleContent?.string else {
            self.set_tip(str: "missing custom routing rule json content")
            return
        }
        if routingRuleName.isEmpty {
            self.set_tip(str: "missing custom routing rule name")
            return
        }
        if routingRuleContent.isEmpty {
            self.set_tip(str: "missing custom routing rule json content")
            return
        }

        print("saveManualRouting1",self.routingsTableView.selectedRow,routingRuleName,routingRuleContent)
        if self.routingsTableView.selectedRow > -1 {
            V2rayRoutings.edit(rowIndex: self.routingsTableView.selectedRow, remark: routingRuleName, json: routingRuleContent)
        } else {
            V2rayRoutings.add(remark: routingRuleName, json: routingRuleContent)
        }
        
        
        self.routingsTableView.reloadData()
        
        menuController.showRouting()
    }
    
    func set_tip(str: String) {
        self.errTip.stringValue = str
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.errTip.stringValue = ""
        }
    }
    
    func loadJsonData(rowIndex: Int) {
        print("loadJsonData", rowIndex)
        if let item = V2rayRoutings.load(idx: rowIndex) {
            self.routingRuleName.stringValue = item.remark
            self.routingRuleContent.string = item.json
        }
    }

    
    @IBAction func addRemoveServer(_ sender: NSSegmentedCell) {
        // 0 add,1 remove
        let seg = addRemoveButton.indexOfSelectedItem
        print("addRemoveServer",seg)
        DispatchQueue.global().async {
            switch seg {
                // add server config
            case 0:
                // add
                V2rayRoutings.add(remark: "new-rule", json: self.default_rule_content)
                
                DispatchQueue.main.sync {
                    V2rayRoutings.loadConfig()
                    // reload data
                    self.routingsTableView.reloadData()
                    // selected current row
                    self.routingsTableView.selectRowIndexes(NSIndexSet(index: V2rayRoutings.count() - 1) as IndexSet, byExtendingSelection: false)
                }
                break
                
                // delete server config
            case 1:
                DispatchQueue.main.sync {
                    // get seleted index
                    let idx = self.routingsTableView.selectedRow
                    // remove
                    V2rayRoutings.remove(idx: idx)
                    
                    // reload
                    V2rayRoutings.loadConfig()
                    
                    // selected prev row
                    let cnt: Int = V2rayRoutings.count()
                    var rowIndex: Int = idx - 1
                    if idx > 0 && idx < cnt {
                        rowIndex = idx
                    }
                    
                    // reload
                    self.routingsTableView.reloadData()
                    // fix
                    if cnt > 1 {
                        // selected row
                        self.routingsTableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: false)
                    }
                
                    if rowIndex >= 0 {
                        self.loadJsonData(rowIndex: rowIndex)
                    } else {
                        self.routingsTableView.becomeFirstResponder()
                    }
                }
                
                // refresh menu
                menuController.showRouting()
                break
                
                // unknown action
            default:
                return
            }
        }
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
        
        
        // 更新菜单
        menuController.showRouting();

        // set current server item and reload v2ray-core
        V2rayLaunch.restartV2ray()
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

// NSnameSource
extension PreferenceRoutingViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return V2rayRoutings.count()
    }

    // show cell
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let v2rayItemList = V2rayRoutings.list()
        // set cell data
        if v2rayItemList.count >= row {
            return v2rayItemList[row].remark
        }
        return nil
    }

    // edit cell
    func tableView(_ tableView: NSTableView, setObjectValue: Any?, for forTableColumn: NSTableColumn?, row: Int) {
        guard let remark = setObjectValue as? String else {
            NSLog("remark is nil")
            return
        }
        DispatchQueue.global().async {
            // edit item remark
            V2rayRoutings.edit(rowIndex: row, remark: remark)
            // reload table
            DispatchQueue.main.async {
                tableView.reloadData()
            }
            // reload menu
            menuController.showRouting()
        }
    }
}

// NSTableViewDelegate
extension PreferenceRoutingViewController: NSTableViewDelegate {
    // For NSTableViewDelegate
    func tableViewSelectionDidChange(_ notification: Notification) {
        self.loadJsonData(rowIndex: self.routingsTableView.selectedRow)
        self.errTip.stringValue = ""
    }

    // Drag & Drop reorder rows
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: NSPasteboard.PasteboardType(rawValue: tableViewDragType))
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return NSDragOperation()
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:], using: {
            (draggingItem: NSDraggingItem, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            if let str = (draggingItem.item as! NSPasteboardItem).string(forType: NSPasteboard.PasteboardType(rawValue: self.tableViewDragType)),
               let index = Int(str) {
                oldIndexes.append(index)
            }
        })

        var oldIndexOffset = 0
        var newIndexOffset = 0
        var oldIndexLast = 0
        var newIndexLast = 0

        // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
        // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
        for oldIndex in oldIndexes {
            if oldIndex < row {
                oldIndexLast = oldIndex + oldIndexOffset
                newIndexLast = row - 1
                oldIndexOffset -= 1
            } else {
                oldIndexLast = oldIndex
                newIndexLast = row + newIndexOffset
                newIndexOffset += 1
            }
        }
        DispatchQueue.global().async {
            print("move",oldIndexLast,newIndexLast)
            // move
            V2rayRoutings.move(oldIndex: oldIndexLast, newIndex: newIndexLast)
            DispatchQueue.main.async {
                // set selected
                self.routingsTableView.selectRowIndexes(NSIndexSet(index: newIndexLast) as IndexSet, byExtendingSelection: false)
                // reload table
                self.routingsTableView.reloadData()
            }
            // reload menu
            menuController.showRouting()
        }
        return true
    }
}
