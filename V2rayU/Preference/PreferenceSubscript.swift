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
    
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!

    @IBOutlet var tableView: NSTableView!
    
    // our variable
    var data: [[String: String]] = [[:]]
    
    override var nibName: NSNib.Name? {
        return "PreferenceSubscript"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
        
        // adding people
        data = [
            [
                "firstName" : "Ragnar",
                "lastName" : "Lothbrok",
            ],
            [
                "firstName" : "Bjorn",
                "lastName" : "Lothbrok",
            ],
            [
                "firstName" : "Harald",
                "lastName" : "Finehair",
            ]
        ]
        
        // reload tableview
        self.tableView.reloadData()
    }
}

extension PreferenceSubscriptViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return (data.count)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let person = data[row]
        print("person",person)

        guard let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
        print("cell",person)
//        cell.textField?.stringValue = person[tableColumn!.identifier.rawValue]!
        
        return cell
    }
}
