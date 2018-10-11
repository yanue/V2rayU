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
    }

    func windowWillClose(_ notification: Notification) {
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
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
