//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import WebKit


class ConfigWindow: NSWindowController,NSTextFieldDelegate {
    let configServer = ConfigServer()

    @IBAction func edit(_ sender: Any) {
        print("edit")
    }
    override var windowNibName: String? {
        return "Config" // no extension .xib here
    }
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var remark: NSTextFieldCell!
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
            self.tableView.selectRowIndexes(NSIndexSet(index: configServer.count()-1) as IndexSet, byExtendingSelection: false)
            
            // refresh menu
//            appDelegate.showServers(list:list)
//            self.openEdit(tableView.NSTextFieldCell)
            
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
            let cnt:Int = configServer.count()
            var rowIndex:Int = idx-1
            if rowIndex < 0 {
                rowIndex = cnt-1
            }
            if rowIndex >= 0 {
                self.tableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: false)
            }
            
            // refresh menu
            appDelegate.showServers(list:list)
            //        let serverItems : NSMenuItem = NSMenuItem()
            break
            // unknown action
        default :
            return
        }
    }
    
    @IBAction func editCell(_ sender: NSTextFieldCell) {
        print("open edit")
    }
    
    @IBAction func ok(_ sender: NSButton) {
        // todo save
        
        // self close
        self.close()
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }
    
    @IBAction func cancel(_ sender: NSButton) {
        // self close
        self.close()
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.tableView.delegate = self as? NSTableViewDelegate
        self.tableView.dataSource = self
        self.tableView.action = #selector(onItemClicked)
        self.tableView.doubleAction = #selector(onDoubleClicked)

//        self.remark.action = #selector(onEdit)
//        self.tableView.target
    }
    @objc private func onEdit() {
        print("onEdit")
    }
    @objc private func onDoubleClicked() {
        print("onDoubleClicked row \(tableView.clickedRow), col \(tableView.clickedColumn) clicked")
    }
    
    @objc private func onItemClicked() {
//        print("row \(tableView.clickedRow), col \(tableView.clickedColumn) clicked")
    }
    
    func windowWillClose(_ notification: Notification) {
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }
    func controlTextDidChange(_ obj: Notification) {
        print("controlTextDidChange")
        
        // Get the data every time the user writes a character
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        
        if let identifier = tableView.identifier, identifier.rawValue == "remark" {
            print("myTableView1")
        }
                let selectedRow = self.tableView.selectedRow
                print("selectedRow",selectedRow)
                // If the user selected a row. (When no row is selected, the index is -1)
                if (selectedRow > -1) {
        //            let myCell = self.tableView.view(atColumn: self.tableView!.column(withIdentifier: "remark"), row: selectedRow, makeIfNecessary: true) as! NSTableCellView
        //
        //            // Get the textField to detect and add it the delegate
        //            let textField = myCell.textField
        //            textField?.delegate = self
                }
    }
    
}

extension ConfigWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return configServer.count()
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let tableViewData = configServer.list()
        return tableViewData[row][(tableColumn?.identifier.rawValue)!]
    }
}
