//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Alamofire

var v2rayConfig: V2rayConfig = V2rayConfig()

class ConfigWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {

    override var windowNibName: String? {
        return "ConfigWindow" // no extension .xib here
    }

    let tableViewDragType: String = "v2ray.item"

    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var okBtn: NSButtonCell!
    @IBOutlet weak var errTip: NSTextField!
    @IBOutlet weak var configText: NSTextView!
    @IBOutlet weak var serversTableView: NSTableView!
    @IBOutlet weak var addRemoveButton: NSSegmentedControl!
    @IBOutlet weak var jsonUrl: NSTextField!
    @IBOutlet weak var selectFileBtn: NSButton!
    @IBOutlet weak var importBtn: NSButton!

    @IBOutlet weak var sockPort: NSButton!
    @IBOutlet weak var httpPort: NSButton!
    @IBOutlet weak var dnsServers: NSButton!
    @IBOutlet weak var enableUdp: NSButton!
    @IBOutlet weak var enableMux: NSButton!
    @IBOutlet weak var muxConcurrent: NSButton!
    @IBOutlet weak var version4: NSButton!

    @IBOutlet weak var switchProtocol: NSPopUpButton!

    @IBOutlet weak var serverView: NSView!
    @IBOutlet weak var VmessView: NSView!
    @IBOutlet weak var ShadowsocksView: NSView!
    @IBOutlet weak var SocksView: NSView!
    @IBOutlet weak var TrojanView: NSView!

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
    @IBOutlet weak var shadowsockMethod: NSPopUpButton!

    // socks5
    @IBOutlet weak var socks5Addr: NSTextField!
    @IBOutlet weak var socks5Port: NSTextField!
    @IBOutlet weak var socks5User: NSTextField!
    @IBOutlet weak var socks5Pass: NSTextField!

    // for trojan
    @IBOutlet weak var trojanAddr: NSTextField!
    @IBOutlet weak var trojanPort: NSTextField!
    @IBOutlet weak var trojanPass: NSTextField!
    @IBOutlet weak var trojanAlpn: NSTextField!

    @IBOutlet weak var networkView: NSView!

    @IBOutlet weak var tcpView: NSView!
    @IBOutlet weak var kcpView: NSView!
    @IBOutlet weak var dsView: NSView!
    @IBOutlet weak var wsView: NSView!
    @IBOutlet weak var h2View: NSView!
    @IBOutlet weak var quicView: NSView!

    @IBOutlet weak var switchNetwork: NSPopUpButton!

    // kcp setting
    @IBOutlet weak var kcpMtu: NSTextField!
    @IBOutlet weak var kcpTti: NSTextField!
    @IBOutlet weak var kcpUplinkCapacity: NSTextField!
    @IBOutlet weak var kcpDownlinkCapacity: NSTextField!
    @IBOutlet weak var kcpReadBufferSize: NSTextField!
    @IBOutlet weak var kcpWriteBufferSize: NSTextField!
    @IBOutlet weak var kcpHeader: NSPopUpButton!
    @IBOutlet weak var kcpCongestion: NSButton!

    @IBOutlet weak var tcpHeaderType: NSPopUpButton!

    @IBOutlet weak var wsHost: NSTextField!
    @IBOutlet weak var wsPath: NSTextField!

    @IBOutlet weak var h2Host: NSTextField!
    @IBOutlet weak var h2Path: NSTextField!

    @IBOutlet weak var dsPath: NSTextField!

    @IBOutlet weak var quicKey: NSTextField!
    @IBOutlet weak var quicSecurity: NSPopUpButton!
    @IBOutlet weak var quicHeaderType: NSPopUpButton!

    @IBOutlet weak var streamSecurity: NSPopUpButton!
    @IBOutlet weak var streamAllowSecure: NSButton!
    @IBOutlet weak var streamTlsServerName: NSTextField!

    override func awakeFromNib() {
        // set table drag style
        serversTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
        serversTableView.allowsMultipleSelection = true

        if V2rayServer.count() == 0 {
            // add default
            V2rayServer.add(remark: "default", json: "", isValid: false)
        }
        self.shadowsockMethod.removeAllItems()
        self.shadowsockMethod.addItems(withTitles: V2rayOutboundShadowsockMethod)

        self.configText.isAutomaticQuoteSubstitutionEnabled = false
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // table view
        self.serversTableView.delegate = self
        self.serversTableView.dataSource = self
        self.serversTableView.reloadData()
        // tab view
        self.tabView.delegate = self
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

            // selected prev row
            let cnt: Int = V2rayServer.count()
            var rowIndex: Int = idx - 1
            if idx > 0 && idx < cnt {
                rowIndex = idx
            }

            // reload
            self.serversTableView.reloadData()

            // fix
            if cnt > 1 {
                // selected row
                self.serversTableView.selectRowIndexes(NSIndexSet(index: rowIndex) as IndexSet, byExtendingSelection: false)
            }

            if rowIndex >= 0 {
                self.loadJsonData(rowIndex: rowIndex)
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

    // switch tab view
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let item = tabViewItem else {
            print("not found tab view")
            return
        }

        let tab = item.identifier! as! String
        if tab == "Manual" {
            self.switchToManualView()
        } else {
            self.switchToImportView()
        }
    }

    // switch to manual
    func switchToManualView() {
        v2rayConfig = V2rayConfig()

        defer {
            if self.configText.string.count > 0 {
                self.bindDataToView()
            }
        }

        // re parse json
        v2rayConfig.parseJson(jsonText: self.configText.string)
        if v2rayConfig.errors.count > 0 {
            self.errTip.stringValue = v2rayConfig.errors[0]
            return
        }

        self.saveConfig()
    }

    // switch to import
    func switchToImportView() {
        // reset error
        self.errTip.stringValue = ""

        self.exportData()

        v2rayConfig.checkManualValid()

        if v2rayConfig.isValid {
            let jsonText = v2rayConfig.combineManual()
            self.configText.string = jsonText
            self.saveConfig()
        } else {
            self.errTip.stringValue = v2rayConfig.error
        }
    }

    // export data to V2rayConfig
    func exportData() {
        // ========================== server start =======================
        if self.switchProtocol.indexOfSelectedItem >= 0 {
            v2rayConfig.serverProtocol = self.switchProtocol.titleOfSelectedItem!
        }

        // vmess
        v2rayConfig.serverVmess.address = self.vmessAddr.stringValue
        v2rayConfig.serverVmess.port = Int(self.vmessPort.intValue)
        var user = V2rayOutboundVMessUser()
        user.alterId = Int(self.vmessAlterId.intValue)
        user.level = Int(self.vmessLevel.intValue)
        user.id = self.vmessUserId.stringValue
        if self.vmessSecurity.indexOfSelectedItem >= 0 {
            user.security = self.vmessSecurity.titleOfSelectedItem!
        }
        v2rayConfig.serverVmess.users[0] = user

        // shadowsocks
        v2rayConfig.serverShadowsocks.address = self.shadowsockAddr.stringValue
        v2rayConfig.serverShadowsocks.port = Int(self.shadowsockPort.intValue)
        v2rayConfig.serverShadowsocks.password = self.shadowsockPass.stringValue
        if self.vmessSecurity.indexOfSelectedItem >= 0 {
            v2rayConfig.serverShadowsocks.method = self.shadowsockMethod.titleOfSelectedItem ?? "aes-256-cfb"
        }

        // socks5
        v2rayConfig.serverSocks5.servers[0].address = self.socks5Addr.stringValue
        v2rayConfig.serverSocks5.servers[0].port = Int(self.socks5Port.intValue)

        var sockUser = V2rayOutboundSockUser()
        sockUser.user = self.socks5User.stringValue
        sockUser.pass = self.socks5Pass.stringValue
        if self.socks5User.stringValue.count > 0 || self.socks5Pass.stringValue.count > 0 {
            v2rayConfig.serverSocks5.servers[0].users = [sockUser]
        } else {
            v2rayConfig.serverSocks5.servers[0].users = nil
        }
        // ========================== server end =======================

        // ========================== stream start =======================
        if self.switchNetwork.indexOfSelectedItem >= 0 {
            v2rayConfig.streamNetwork = self.switchNetwork.titleOfSelectedItem!
        }
        v2rayConfig.streamTlsAllowInsecure = self.streamAllowSecure.state.rawValue > 0
        if self.streamSecurity.indexOfSelectedItem >= 0 {
            v2rayConfig.streamTlsSecurity = self.streamSecurity.titleOfSelectedItem!
        }
        v2rayConfig.streamTlsServerName = self.streamTlsServerName.stringValue

        // tcp
        if self.tcpHeaderType.indexOfSelectedItem >= 0 {
            v2rayConfig.streamTcp.header.type = self.tcpHeaderType.titleOfSelectedItem!
        }

        // kcp
        if self.kcpHeader.indexOfSelectedItem >= 0 {
            v2rayConfig.streamKcp.header.type = self.kcpHeader.titleOfSelectedItem!
        }
        v2rayConfig.streamKcp.mtu = Int(self.kcpMtu.intValue)
        v2rayConfig.streamKcp.tti = Int(self.kcpTti.intValue)
        v2rayConfig.streamKcp.uplinkCapacity = Int(self.kcpUplinkCapacity.intValue)
        v2rayConfig.streamKcp.downlinkCapacity = Int(self.kcpDownlinkCapacity.intValue)
        v2rayConfig.streamKcp.readBufferSize = Int(self.kcpReadBufferSize.intValue)
        v2rayConfig.streamKcp.writeBufferSize = Int(self.kcpWriteBufferSize.intValue)
        v2rayConfig.streamKcp.congestion = self.kcpCongestion.state.rawValue > 0

        // h2
        v2rayConfig.streamH2.host[0] = self.h2Host.stringValue
        v2rayConfig.streamH2.path = self.h2Path.stringValue

        // ws
        v2rayConfig.streamWs.path = self.wsPath.stringValue
        v2rayConfig.streamWs.headers.host = self.wsHost.stringValue

        // domainsocket
        v2rayConfig.streamDs.path = self.dsPath.stringValue

        // quic
        v2rayConfig.streamQuic.key = self.quicKey.stringValue
        if self.quicHeaderType.indexOfSelectedItem >= 0 {
            v2rayConfig.streamQuic.header.type = self.quicHeaderType.titleOfSelectedItem!
        }
        if self.quicSecurity.indexOfSelectedItem >= 0 {
            v2rayConfig.streamQuic.security = self.quicSecurity.titleOfSelectedItem!
        }
        // ========================== stream end =======================
    }

    func bindDataToView() {
        // ========================== base start =======================
        // base
        self.httpPort.title = v2rayConfig.httpPort
        self.sockPort.title = v2rayConfig.socksPort
        self.enableUdp.intValue = v2rayConfig.enableUdp ? 1 : 0
        self.enableMux.intValue = v2rayConfig.enableMux ? 1 : 0
        self.muxConcurrent.intValue = Int32(v2rayConfig.mux)
        self.version4.intValue = v2rayConfig.isNewVersion ? 1 : 0
        // ========================== base end =======================

        // ========================== server start =======================
        self.switchProtocol.selectItem(withTitle: v2rayConfig.serverProtocol)
        self.switchOutboundView(protocolTitle: v2rayConfig.serverProtocol)

        // vmess
        self.vmessAddr.stringValue = v2rayConfig.serverVmess.address
        self.vmessPort.intValue = Int32(v2rayConfig.serverVmess.port)
        if v2rayConfig.serverVmess.users.count > 0 {
            let user = v2rayConfig.serverVmess.users[0]
            self.vmessAlterId.intValue = Int32(user.alterId)
            self.vmessLevel.intValue = Int32(user.level)
            self.vmessUserId.stringValue = user.id
            self.vmessSecurity.selectItem(withTitle: user.security)
        }

        // shadowsocks
        self.shadowsockAddr.stringValue = v2rayConfig.serverShadowsocks.address
        if v2rayConfig.serverShadowsocks.port > 0 {
            self.shadowsockPort.stringValue = String(v2rayConfig.serverShadowsocks.port)
        }
        self.shadowsockPass.stringValue = v2rayConfig.serverShadowsocks.password
        self.shadowsockMethod.selectItem(withTitle: v2rayConfig.serverShadowsocks.method)

        // socks5
        self.socks5Addr.stringValue = v2rayConfig.serverSocks5.servers[0].address
        self.socks5Port.stringValue = String(v2rayConfig.serverSocks5.servers[0].port)
        if let users = v2rayConfig.serverSocks5.servers[0].users, users.count > 0 {
            self.socks5User.stringValue = users[0].user
            self.socks5Pass.stringValue = users[0].pass
        }
        // ========================== server end =======================

        // ========================== stream start =======================
        self.switchNetwork.selectItem(withTitle: v2rayConfig.streamNetwork)
        self.switchSteamView(network: v2rayConfig.streamNetwork)

        self.streamAllowSecure.intValue = v2rayConfig.streamTlsAllowInsecure ? 1 : 0
        self.streamSecurity.selectItem(withTitle: v2rayConfig.streamTlsSecurity)
        self.streamTlsServerName.stringValue = v2rayConfig.streamTlsServerName

        // tcp
        self.tcpHeaderType.selectItem(withTitle: v2rayConfig.streamTcp.header.type)

        // kcp
        self.kcpHeader.selectItem(withTitle: v2rayConfig.streamKcp.header.type)
        self.kcpMtu.intValue = Int32(v2rayConfig.streamKcp.mtu)
        self.kcpTti.intValue = Int32(v2rayConfig.streamKcp.tti)
        self.kcpUplinkCapacity.intValue = Int32(v2rayConfig.streamKcp.uplinkCapacity)
        self.kcpDownlinkCapacity.intValue = Int32(v2rayConfig.streamKcp.downlinkCapacity)
        self.kcpReadBufferSize.intValue = Int32(v2rayConfig.streamKcp.readBufferSize)
        self.kcpWriteBufferSize.intValue = Int32(v2rayConfig.streamKcp.writeBufferSize)
        self.kcpCongestion.intValue = v2rayConfig.streamKcp.congestion ? 1 : 0

        // h2
        self.h2Host.stringValue = v2rayConfig.streamH2.host.count > 0 ? v2rayConfig.streamH2.host[0] : ""
        self.h2Path.stringValue = v2rayConfig.streamH2.path

        // ws
        self.wsPath.stringValue = v2rayConfig.streamWs.path
        self.wsHost.stringValue = v2rayConfig.streamWs.headers.host

        // domainsocket
        self.dsPath.stringValue = v2rayConfig.streamDs.path

        // quic
        self.quicKey.stringValue = v2rayConfig.streamQuic.key
        self.quicSecurity.selectItem(withTitle: v2rayConfig.streamQuic.security)
        self.quicHeaderType.selectItem(withTitle: v2rayConfig.streamQuic.header.type)

        // ========================== stream end =======================
    }

    func loadJsonData(rowIndex: Int) {
        defer {
            self.bindDataToView()
            // replace current
            self.switchToImportView()
        }

        // reset
        v2rayConfig = V2rayConfig()
        if rowIndex < 0 {
            return
        }

        let item = V2rayServer.loadV2rayItem(idx: rowIndex)
        self.configText.string = item?.json ?? ""
        v2rayConfig.isValid = item?.isValid ?? false
        self.jsonUrl.stringValue = item?.url ?? ""

        v2rayConfig.parseJson(jsonText: self.configText.string)
        if v2rayConfig.errors.count > 0 {
            self.errTip.stringValue = v2rayConfig.errors[0]
            return
        }
    }

    func saveConfig() {
        let text = self.configText.string

        v2rayConfig.parseJson(jsonText: self.configText.string)
        if v2rayConfig.errors.count > 0 {
            self.errTip.stringValue = v2rayConfig.errors[0]
        }

        // save
        let errMsg = V2rayServer.save(idx: self.serversTableView.selectedRow, isValid: v2rayConfig.isValid, jsonData: text)
        if errMsg.count == 0 {
            if self.errTip.stringValue == "" {
                self.errTip.stringValue = "save success"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // your code here
                    self.errTip.stringValue = ""
                }
            }
            self.refreshServerList(ok: errMsg.count == 0)
        } else {
            self.errTip.stringValue = errMsg
        }
    }

    func refreshServerList(ok: Bool = true) {
        // refresh menu
        menuController.showServers()
        // if server is current
        if let curName = UserDefaults.get(forKey: .v2rayCurrentServerName) {
            let v2rayItemList = V2rayServer.list()
            if curName == v2rayItemList[self.serversTableView.selectedRow].name {
                if ok {
                    menuController.startV2rayCore()
                } else {
                    menuController.stopV2rayCore()
                }
            }
        }
    }

    @IBAction func ok(_ sender: NSButton) {
        // set always on
        self.okBtn.state = .on
        // in Manual tab view
        if "Manual" == self.tabView.selectedTabViewItem?.identifier as! String {
            self.switchToImportView()
        } else {
            self.saveConfig()
        }
    }

    @IBAction func importConfig(_ sender: NSButton) {
        self.configText.string = ""
        if jsonUrl.stringValue.trimmingCharacters(in: .whitespaces) == "" {
            self.errTip.stringValue = "error: invaid url"
            return
        }

        self.importJson()
    }

    func saveImport(importUri: ImportUri) {
        if importUri.isValid {
            self.configText.string = importUri.json
            if importUri.remark.count > 0 {
                V2rayServer.edit(rowIndex: self.serversTableView.selectedRow, remark: importUri.remark)
            }

            // refresh
            self.refreshServerList(ok: true)
        } else {
            self.errTip.stringValue = importUri.error
        }
    }

    func importJson() {
        let text = self.configText.string
        let uri = jsonUrl.stringValue.trimmingCharacters(in: .whitespaces)
        // edit item remark
        V2rayServer.edit(rowIndex: self.serversTableView.selectedRow, url: uri)

        if let importUri = ImportUri.importUri(uri: uri, checkExist: false) {
            self.saveImport(importUri: importUri)
        } else {
            // download json file
            Alamofire.request(jsonUrl.stringValue).responseString { DataResponse in
                if (DataResponse.error != nil) {
                    self.errTip.stringValue = "error: " + DataResponse.error.debugDescription
                    return
                }

                if DataResponse.value != nil {
                    self.configText.string = v2rayConfig.formatJson(json: DataResponse.value ?? text)
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

    @IBAction func goQuicHelp(_ sender: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/transport/quic.html") else {
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

    @IBAction func goVersionHelp(_ sender: Any) {
        guard let url = URL(string: "https://www.v2ray.com/chapter_02/01_overview.html") else {
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

    func switchSteamView(network: String) {
        networkView.subviews.forEach {
            $0.isHidden = true
        }

        switch network {
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
        case "quic":
            self.quicView.isHidden = false
            break;
        default: // vmess
            self.tcpView.isHidden = false
            break
        }
    }

    func switchOutboundView(protocolTitle: String) {
        serverView.subviews.forEach {
            $0.isHidden = true
        }

        switch protocolTitle {
        case "vmess":
            self.VmessView.isHidden = false
            break;
        case "shadowsocks":
            self.ShadowsocksView.isHidden = false
            break;
        case "socks":
            self.SocksView.isHidden = false
            break;
        case "trojan":
            self.TrojanView.isHidden = false
            break;
        default: // vmess
            self.VmessView.isHidden = true
            break
        }
    }

    @IBAction func switchSteamNetwork(_ sender: NSPopUpButtonCell) {
        if let item = switchNetwork.selectedItem {
            self.switchSteamView(network: item.title)
        }
    }

    @IBAction func switchOutboundProtocol(_ sender: NSPopUpButtonCell) {
        if let item = switchProtocol.selectedItem {
            self.switchOutboundView(protocolTitle: item.title)
        }
    }

    @IBAction func switchUri(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem else {
            return
        }
        // url
        if item.title == "url" {
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

    @IBAction func clearLogs(_ sender: NSButton) {
        V2rayLaunch.ClearLogs()
    }

    @IBAction func cancel(_ sender: NSButton) {
        // hide dock icon and close all opened windows
        _ = menuController.showDock(state: false)
    }

    @IBAction func goAdvanceSetting(_ sender: Any) {
        preferencesWindowController.show(preferencePane: .advanceTab)
    }

    @IBAction func goSubscribeSetting(_ sender: Any) {
        preferencesWindowController.show(preferencePane: .subscribeTab)
    }

    @IBAction func goRoutingRuleSetting(_ sender: Any) {
        preferencesWindowController.show(preferencePane: .routingTab)
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
        // edit item remark
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
        self.loadJsonData(rowIndex: self.serversTableView.selectedRow)
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
