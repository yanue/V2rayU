//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences
import ServiceManagement

final class PreferenceSubscriptViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.subscriptTab
    let preferencePaneTitle = "Subscript"
    let toolbarItemIcon = NSImage(named: NSImage.userAccountsName)!
    let tableViewDragType: String = "v2ray.subscript"

    @IBOutlet weak var remark: NSTextField!
    @IBOutlet weak var url: NSTextField!
    @IBOutlet var tableView: NSTableView!

    // our variable
    override var nibName: NSNib.Name? {
        return "PreferenceSubscript"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);

        // reload tableview
        V2raySubscript.loadConfig()
    }

    @IBAction func addSubscript(_ sender: Any) {
        var url = self.url.stringValue
        var remark = self.remark.stringValue
        // trim
        url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        remark = remark.trimmingCharacters(in: .whitespacesAndNewlines)

        if url.count == 0 {
            self.url.becomeFirstResponder()
            return
        }

        if !url.isValidUrl() {
            self.url.becomeFirstResponder()
            print("url is invalid")
            return
        }

        if remark.count == 0 {
            self.remark.becomeFirstResponder()
            return
        }

        // add to server
        V2raySubscript.add(remark: remark, url: url)

        // reset
        self.remark.stringValue = ""
        self.url.stringValue = ""

        // reload tableview
        self.tableView.reloadData()
    }

    @IBAction func removeSubscript(_ sender: Any) {
        let idx = self.tableView.selectedRow
        if self.tableView.selectedRow > -1 {
            // remove
            V2raySubscript.remove(idx: idx)

            // selected prev row
            let cnt: Int = V2raySubscript.count()
            var rowIndex: Int = idx - 1
            if idx > 0 && idx < cnt {
                rowIndex = idx
            }
            if rowIndex == -1 {
                rowIndex = 0
            }

            // reload tableview
            self.tableView.reloadData()

            // fix
            if cnt > 0 {
                // selected row
                self.tableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: true)
            }
        }
    }

    // update servers from subscript url list
    @IBAction func updateSubscript(_ sender: Any) {
        print("updateSubscript")
        self.tableView.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: true)
    }
}

extension PreferenceSubscriptViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return V2raySubscript.count()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier as NSString?
        var data = V2raySubscript.list()
        if (identifier == "remarkCell") {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "remarkCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = data[row].remark
            return cell
        } else if (identifier == "urlCell") {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "urlCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = data[row].url
            return cell
        }
        return nil
    }
}
