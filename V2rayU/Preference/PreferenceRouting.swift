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
    @IBOutlet weak var proxyTextView: NSTextView!
    @IBOutlet weak var directTextView: NSTextView!
    @IBOutlet weak var blockTextView: NSTextView!
    @IBOutlet weak var routingRuleContent: NSTextView!
    @IBOutlet weak var routingRuleName: NSTextField!
    @IBOutlet weak var defaulRoutingRuleName: NSTextField!
    @IBOutlet weak var errTip: NSTextField!
    @IBOutlet weak var routingsTableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!
    @IBOutlet weak var customView: NSView!
    @IBOutlet weak var defaultView: NSView!
    
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
    }
    
    func set_tip(str: String) {
        self.errTip.stringValue = str
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.errTip.stringValue = ""
        }
    }
    
    func loadJsonData(rowIndex: Int) {
        print("loadJsonData", rowIndex)
        DispatchQueue.main.async {
            self.defaultView.isHidden = true
            self.customView.isHidden = true
            if let item = V2rayRoutings.load(idx: rowIndex) {
                let isDefaultRule = V2rayRoutings.isDefaultRule(name: item.name)
                print("loadJsonData", item.domainStrategy,item.proxy,item.direct,item.block,item.json,isDefaultRule)
                if isDefaultRule {
                    self.defaultView.isHidden = false
                    self.domainStrategy.selectItem(withTitle: item.domainStrategy)
                    self.proxyTextView.string = item.proxy
                    self.directTextView.string = item.direct
                    self.blockTextView.string = item.block
                    self.defaulRoutingRuleName.stringValue = item.remark
                } else {
                    self.customView.isHidden = false
                    self.routingRuleName.stringValue = item.remark
                    self.routingRuleContent.string = item.json
                }
            }
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
                V2rayRoutings.add(remark: "new-rule", json: V2rayRoutings.default_rule_content)
                
                DispatchQueue.main.async {
                    V2rayRoutings.loadConfig()
                    // reload data
                    self.routingsTableView.reloadData()
                    // selected current row
                    self.routingsTableView.selectRowIndexes(NSIndexSet(index: V2rayRoutings.count() - 1) as IndexSet, byExtendingSelection: false)
                }
                break
                
                // delete server config
            case 1:
                DispatchQueue.main.async {
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
        let selectedRule = self.routingsTableView.selectedRow
        if selectedRule == -1 {
            return
        }
        guard let rule = V2rayRoutings.load(idx: selectedRule) else {
            return
        }

        if V2rayRoutings.isDefaultRule(name: rule.name) {
            let domainStrategy = self.domainStrategy.titleOfSelectedItem
            if domainStrategy != nil {
                rule.domainStrategy = domainStrategy!
            }
            rule.proxy = self.proxyTextView.string
            rule.direct = self.directTextView.string
            rule.block = self.blockTextView.string
        } else {
            rule.remark = self.routingRuleName.stringValue
            let (res, err) = parseRoutingRuleJson(json: self.routingRuleContent.string) 
            if err != nil {
                print("parseRoutingRuleJson err", err)
                self.errTip.stringValue = "parse json err: \(err)"
                // hide err     
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.errTip.stringValue = ""
                }
                return
            } else {
                self.errTip.stringValue = ""
                rule.json = self.routingRuleContent.string
            }
        }
        
        // save update
        V2rayRoutings.save(routing: rule)

       // reload table
        self.routingsTableView.reloadData()
        // set selected
        self.routingsTableView.selectRowIndexes(NSIndexSet(index: selectedRule) as IndexSet, byExtendingSelection: false)
        
        // 更新菜单
        menuController.showRouting();
        // if is selected rule name == rule.name, restart v2ray
        let selectedRuleName = UserDefaults.get(forKey: .routingSelectedRule)
        if selectedRuleName == rule.name {
            // restart v2ray
            V2rayLaunch.restartV2ray()
        }
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
}

// NSTableViewDelegate
extension PreferenceRoutingViewController: NSTableViewDelegate {
    // For NSTableViewDelegate
    func tableViewSelectionDidChange(_ notification: Notification) {
        // Ensure there's a valid selected row before calling loadJsonData
        if self.routingsTableView.selectedRow >= 0 {
            self.loadJsonData(rowIndex: self.routingsTableView.selectedRow)
        } else {
            // Handle the case where no row is selected or add a default behavior
            print("No row selected")
        }
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
