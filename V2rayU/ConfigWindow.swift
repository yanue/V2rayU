//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import WebKit
import Alamofire

class ConfigWindowController: NSWindowController, NSWindowDelegate {
    // closed by window 'x' button
    var closedByWindowButton: Bool = false

    override var windowNibName: String? {
        return "ConfigWindow" // no extension .xib here
    }

    let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController
    let tableViewDragType: String = "v2ray.item"

    @IBOutlet weak var errTip: NSTextField!
    @IBOutlet weak var configText: NSTextView!
    @IBOutlet weak var serversTableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!
    @IBOutlet weak var logLevel: NSPopUpButton!
    @IBOutlet weak var jsonUrl: NSTextField!
    @IBOutlet weak var selectFileBtn: NSButton!
    @IBOutlet weak var importBtn: NSButton!
    
    @IBOutlet weak var sockPort: NSTextField!
    @IBOutlet weak var httpPort: NSTextField!
    @IBOutlet weak var dnsServers: NSTextField!
    @IBOutlet weak var enableUdp: NSButton!
    @IBOutlet weak var enableMux: NSButton!
    @IBOutlet weak var muxConcurrent: NSTextField!

    @IBOutlet weak var switchProtocol: NSPopUpButton!
    
    @IBOutlet weak var serverView: NSView!
    @IBOutlet weak var VmessView: NSView!
    @IBOutlet weak var ShadowsocksView: NSView!
    @IBOutlet weak var SocksView: NSView!
    
    // vmess
    @IBOutlet weak var vmessAddr: NSTextField!
    @IBOutlet weak var vmessPort: NSTextField!
    @IBOutlet weak var vmessAlterId: NSTextField!
    @IBOutlet weak var vmessLevel: NSTextField!
    @IBOutlet weak var vmessUserId: NSTextField!
    @IBOutlet weak var vmessSecurity: NSPopUpButton!
    
    // shadowsocks
    @IBOutlet weak var shadowsockAddr: NSTextField!
    @IBOutlet weak var shadowsockPort: NSTextField!
    @IBOutlet weak var shadowsockPass: NSTextField!
    @IBOutlet weak var shadowsockSecurity: NSPopUpButton!

    // socks5
    @IBOutlet weak var socksAddr: NSTextField!
    @IBOutlet weak var socksPort: NSTextField!
    @IBOutlet weak var socksUser: NSTextField!
    @IBOutlet weak var socksPass: NSTextField!

    @IBOutlet weak var networkView: NSView!

    @IBOutlet weak var tcpView: NSView!
    @IBOutlet weak var kcpView: NSView!
    @IBOutlet weak var dsView: NSView!
    @IBOutlet weak var wsView: NSView!
    @IBOutlet weak var h2View: NSView!

    @IBOutlet weak var switchNetwork: NSPopUpButton!
    
    // kcp setting
    @IBOutlet weak var kcpMtu: NSTextField!
    @IBOutlet weak var kcpTti: NSTextField!
    @IBOutlet weak var kcpUplinkCapacity: NSTextField!
    @IBOutlet weak var kcpDownlinkCapacity: NSTextField!
    @IBOutlet weak var kcpReadBufferSize: NSTextField!
    @IBOutlet weak var kcpWriteBufferSize: NSTextField!
    @IBOutlet weak var kcpHeader: NSPopUpButton!
    @IBOutlet weak var kcpSuggest: NSButton!
    
    @IBOutlet weak var tcpHeaderType: NSPopUpButton!
    
    @IBOutlet weak var wsHost: NSTextField!
    @IBOutlet weak var wsPath: NSTextField!
    
    @IBOutlet weak var h2Host: NSTextField!
    @IBOutlet weak var h2Path: NSTextField!

    @IBOutlet weak var dsPath: NSTextField!
    
    @IBOutlet weak var streamSecurity: NSPopUpButton!
    @IBOutlet weak var streamAllowSecure: NSButton!
    @IBOutlet weak var streamTlsServerName: NSTextField!
    
    override func awakeFromNib() {
        // set table drag style
        serversTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
        serversTableView.allowsMultipleSelection = true
        // windowWillClose Notification
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
//        comboUri.selectItem(at: 0)

        self.serversTableView.delegate = self
        self.serversTableView.dataSource = self
        self.serversTableView.reloadData()

        if let level = UserDefaults.get(forKey: .v2rayLogLevel) {
            logLevel.selectItem(withTitle: level)
        }
    }

    @IBAction func addRemoveServer(_ sender: NSSegmentedCell) {
        // 0 add,1 remove
        let seg = addRemoveButton.indexOfSelectedItem

        switch seg {
                // add server config
        case 0:
            // add
            _ = V2rayServer.add()

            // reload data
            self.serversTableView.reloadData()
            // selected current row
            self.serversTableView.selectRowIndexes(NSIndexSet(index: V2rayServer.count() - 1) as IndexSet, byExtendingSelection: false)

            break

                // delete server config
        case 1:
            // get seleted index
            let idx = self.serversTableView.selectedRow

            // remove
            V2rayServer.remove(idx: idx)

            // reload
            self.serversTableView.reloadData()

            // selected prev row
            let cnt: Int = V2rayServer.count()
            var rowIndex: Int = idx - 1
            if rowIndex < 0 {
                rowIndex = cnt - 1
            }
            if rowIndex >= 0 {
                self.loadJsonFile(rowIndex: rowIndex)
            } else {
                self.serversTableView.becomeFirstResponder()
            }

            // refresh menu
            menuController.showServers()
            break

                // unknown action
        default:
            return
        }
    }

    func loadJsonFile(rowIndex: Int) {
        if rowIndex < 0 {
            return
        }

        let v2ray = V2rayServer.loadV2rayItem(idx: rowIndex)
        self.configText.string = v2ray?.json ?? ""
    }

    func saveConfig() {
        // todo save
        let text = self.configText.string

        self.errTip.stringValue = V2rayConfig().saveByJson(jsonText: text)
        return
        // save
        let errMsg = V2rayServer.save(idx: self.serversTableView.selectedRow, jsonData: text)
        self.errTip.stringValue = errMsg

        // refresh menu
        menuController.showServers()
        // if server is current
        if let curName = UserDefaults.get(forKey: .v2rayCurrentServerName) {
            let v2rayItemList = V2rayServer.list()
            if curName == v2rayItemList[self.serversTableView.selectedRow].name {
                if errMsg != "" {
                    menuController.stopV2rayCore()
                } else {
                    menuController.startV2rayCore()
                }
            }
        }
    }

    @IBAction func ok(_ sender: NSButton) {
        self.saveConfig()
    }

    @IBAction func cancel(_ sender: NSButton) {
        // self close
        self.close()
        // hide dock icon and close all opened windows
//        NSApp.setActivationPolicy(.accessory)
    }

    @IBAction func setV2rayLogLevel(_ sender: NSPopUpButton) {
        if let item = logLevel.selectedItem {
            UserDefaults.set(forKey: .v2rayLogLevel, value: item.title)
            // restart service
            menuController.startV2rayCore()
        }
    }

    @IBAction func importConfig(_ sender: NSButton) {
        self.configText.string = ""
        if jsonUrl.stringValue == "" {
            self.errTip.stringValue = "error: invaid url"
            return
        }

        self.importJson()
    }

    func importJson() {
        let text = self.configText.string

        // download json file
        Alamofire.request(jsonUrl.stringValue).responseString { DataResponse in
            if (DataResponse.error != nil) {
                self.errTip.stringValue = "error: " + DataResponse.error.debugDescription
                return
            }

            if DataResponse.value != nil {
                self.configText.string = DataResponse.value ?? text

                // save
                let msg = V2rayServer.save(idx: self.serversTableView.selectedRow, jsonData: self.configText.string)
                if msg != "" {
                    self.saveConfig()
                }
            }
        }
    }

    @IBAction func goTcpHelp(_ sender: NSButtonCell) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/transport/tcp.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goDsHelp(_ sender: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/transport/domainsocket.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goProtocolHelp(_ sender: NSButton) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/protocols/vmess.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goStreamHelp(_ sender: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/05_transport.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func switchSteamNetwork(_ sender: NSPopUpButtonCell) {
        networkView.subviews.forEach { $0.isHidden = true }
        
        if let item = switchNetwork.selectedItem {
            print("item",item.title)
            
            switch item.title {
            case "tcp":
                self.tcpView.isHidden = false
                break;
            case "kcp":
                self.kcpView.isHidden = false
                break;
            case "domainsocket":
                self.dsView.isHidden = false
                break;
            case "ws":
                self.wsView.isHidden = false
                break;
            case "h2":
                self.h2View.isHidden = false
                break;
            default: // vmess
                self.tcpView.isHidden = false
                break
            }
        }
    }
    
    @IBAction func switchOutboundProtocol(_ sender: NSPopUpButtonCell) {
        serverView.subviews.forEach { $0.isHidden = true }
        
        if let item = switchProtocol.selectedItem {
            switch item.title {
            case "vmess":
                self.VmessView.isHidden = false
                break;
            case "shadowsocks":
                self.ShadowsocksView.isHidden = false
                break;
            case "socks5":
                self.SocksView.isHidden = false
                break;
            default: // vmess
                self.SocksView.isHidden = true
                break
            }
        }
    }
    
    @IBAction func switchUri(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }
        // Url
        if item.title == "Url" {
            jsonUrl.stringValue = ""
            selectFileBtn.isHidden = true
            importBtn.isHidden = false
            jsonUrl.isEditable = true
        } else {
            // local file
            jsonUrl.stringValue = ""
            selectFileBtn.isHidden = false
            importBtn.isHidden = true
            jsonUrl.isEditable = false
        }
    }

    @IBAction func browseFile(_ sender: NSButton) {
        jsonUrl.stringValue = ""
        let dialog = NSOpenPanel()

        dialog.title = "Choose a .json file";
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canChooseDirectories = true;
        dialog.canCreateDirectories = true;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes = ["json", "txt"];

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file

            if (result != nil) {
                jsonUrl.stringValue = result?.absoluteString ?? ""
                self.importJson()
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    @IBAction func openLogs(_ sender: NSButton) {
        V2rayLaunch.OpenLogs()
    }

    func windowWillClose(_ notification: Notification) {
        // closed by window 'x' button
        self.closedByWindowButton = true
        // hide dock icon and close all opened windows
//        NSApp.setActivationPolicy(.accessory)
    }
}

// NSv2rayItemListSource
extension ConfigWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return V2rayServer.count()
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let v2rayItemList = V2rayServer.list()
        // set cell data
        return v2rayItemList[row].remark
    }

    // edit cell
    func tableView(_ tableView: NSTableView, setObjectValue: Any?, for forTableColumn: NSTableColumn?, row: Int) {
        guard let remark = setObjectValue as? String else {
            NSLog("remark is nil")
            return
        }
        // edit item
        V2rayServer.edit(rowIndex: row, remark: remark)
        // reload table
        tableView.reloadData()
        // reload menu
        menuController.showServers()
    }
}

// NSTableViewDelegate
extension ConfigWindowController: NSTableViewDelegate {
    // For NSTableViewDelegate
    func tableViewSelectionDidChange(_ notification: Notification) {
        self.loadJsonFile(rowIndex: self.serversTableView.selectedRow)
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

        // move
        V2rayServer.move(oldIndex: oldIndexLast, newIndex: newIndexLast)
        // set selected
        self.serversTableView.selectRowIndexes(NSIndexSet(index: newIndexLast) as IndexSet, byExtendingSelection: false)
        // reload table
        self.serversTableView.reloadData()
        // reload menu
        menuController.showServers()

        return true
    }
}
