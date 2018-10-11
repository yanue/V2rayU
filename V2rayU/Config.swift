//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import WebKit


class ConfigWindow: NSWindowController {
    let configServer = ConfigServer()

    override var windowNibName: String? {
        return "Config" // no extension .xib here
    }

    @IBOutlet weak var configText: NSTextView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!

    @IBAction func addRemoveServer(_ sender: NSSegmentedCell) {
        // 0 add,1 remove
        let seg = addRemoveButton.indexOfSelectedItem
        let appDelegate = NSApplication.shared.delegate as! AppDelegate

        switch seg {
                // add server config
        case 0:
            // add
            _ = configServer.add()

            // reload data
            self.tableView.reloadData()
            // selected current row
            self.tableView.selectRowIndexes(NSIndexSet(index: configServer.count() - 1) as IndexSet, byExtendingSelection: false)
            
            break

                // delete server config
        case 1:
            // get seleted index
            let idx = self.tableView.selectedRow

            // remove
            let list = configServer.remove(idx: idx)

            // reload
            self.tableView.reloadData()

            // selected prev row
            let cnt: Int = configServer.count()
            var rowIndex: Int = idx - 1
            if rowIndex < 0 {
                rowIndex = cnt - 1
            }
            if rowIndex >= 0 {
                self.loadServer(rowIndex: rowIndex)
            } else {
                self.tableView.becomeFirstResponder()
            }

            // refresh menu
            appDelegate.showServers(list: list)
            break
                // unknown action
        default:
            return
        }
    }

    func loadServer(rowIndex:Int) {
        self.tableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: false)
        // insert text
//       text
        self.configText.string=configServer.loadFile( idx: rowIndex)

        // focus
//        self.configText.becomeFirstResponder()
    }
    
    @IBAction func editCell(_ sender: NSTextFieldCell) {
        print("open edit")
    }

    @IBAction func ok(_ sender: NSButton) {
        // todo save
        let text = self.configText.string

        configServer.save(text: text, idx: self.tableView.selectedRow)
        // self close
//        self.close()
        // hide dock icon and close all opened windows
//        NSApp.setActivationPolicy(.accessory)
    }

    @IBAction func cancel(_ sender: NSButton) {
        // self close
        self.close()
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.reloadData()

        self.tableView.action = #selector(onItemClicked)
        self.tableView.doubleAction = #selector(onDoubleClicked)
    }

    @objc private func onDoubleClicked() {
        print("onDoubleClicked row \(tableView.clickedRow), col \(tableView.clickedColumn) clicked")
    }

    @objc func onItemClicked() {
        print("row \(tableView.clickedRow), col \(tableView.clickedColumn) clicked")
    }

    func windowWillClose(_ notification: Notification) {
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }
}

// NSTableViewDataSource
extension ConfigWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        print("configServer.count()",configServer.count())
        return configServer.count()
    }
}

// NSTableViewDelegate
extension ConfigWindow: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tableViewData = configServer.source()
        print("tableViewData",tableViewData)
        // get cell Identifier (name is "remark")
        let cellIdentifier: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier(rawValue: (tableColumn?.identifier)!.rawValue)
        
        if let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            // set cell val
            cell.textField?.stringValue = tableViewData[row][cellIdentifier.rawValue]!
            return cell
        }
        
        return nil
    }
    
    //当添加行时调用的回调
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        print("addRow")
    }
    //当移除行时调用的回调
    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        print("removeRow")
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int){
        print("edit")
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        // focus
        self.loadServer(rowIndex: self.tableView.selectedRow)
        // can select
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
//        print("changed")
        //        updateStatus()
    }
}
