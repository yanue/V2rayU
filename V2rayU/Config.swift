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
   
    override var windowNibName: String? {
        return "Config" // no extension .xib here
    }
    
    var tableViewData = [["remark":"hk"],["remark":"us"]]
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!
    
    @IBAction func addRemoveServer(_ sender: NSSegmentedCell) {
        // 0 add,1 remove
        let seg = addRemoveButton.indexOfSelectedItem

        switch seg {
        case 0:
            // add server
           tableViewData = [["remark":"hk"],["remark":"us"],["remark":"jp"]]
           self.tableView.reloadData()
            break
            
        case 1:
            tableViewData = [["remark":"hk"]]
            self.tableView.reloadData()
            // delete server
            break
        default :
            return
        }
    }
    
    @IBAction func openEdit(_ sender: NSTextFieldCell) {
        NSLog("edit")
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
    }

    func windowWillClose(_ notification: Notification) {
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }
}

extension ConfigWindow: NSTableViewDataSource{
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableViewData.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return tableViewData[row][(tableColumn?.identifier.rawValue)!]
    }
}
