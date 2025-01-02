//
//  Advance.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//
import Foundation
import SwiftUI

struct AdvanceView: View {

    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""

    @ObservedObject var appState = AppState.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                    getNumFieldWithLabel(label: "httpPort", num: $appState.httpPort)
            }
        }
        .frame(width: 500, height: 400)

    }
}
