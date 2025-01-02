//
//  Common.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

// 公共的 getTextField 函数，接受 name 和绑定的文本
func getTextField(name: String, text: Binding<String>) -> some View {
    TextField(name, text: text)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.leading, 8)
}

// 公共的 getTextField 函数，接受 name
func getTextLabel(label: String, labelWidth: CGFloat = 120) -> some View {
    Text(label).frame(width: labelWidth, alignment: .trailing)
}

@MainActor
func getTextFieldWithLabel(label: String, text: Binding<String>, labelWidth: CGFloat = 120) -> some View {
    HStack {
        Text(label).frame(width: labelWidth, alignment: .trailing)
        Spacer()
        TextField(label, text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.leading, 7)
    }
}

@MainActor
func getNumFieldWithLabel(label: String, num: Binding<Int>, labelWidth: CGFloat = 120) -> some View {
        HStack {
            Text(label).frame(width: labelWidth, alignment: .trailing)
            Spacer()
            TextField(label, value: num, formatter: NumberFormatter())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.leading, 7)
        }
}

@MainActor
func getPickerWithLabel<T: CaseIterable & RawRepresentable & Hashable>(label: String, selection: Binding<T>, labelWidth: CGFloat = 120) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    HStack {
        Text(label)
            .frame(width: labelWidth, alignment: .trailing)
        Spacer()
        Picker("", selection: selection) {
            ForEach(T.allCases, id: \.self) { pick in
                Text(pick.rawValue)
            }
        }
        .pickerStyle(MenuPickerStyle())  // 可以根据需要修改样式
    }
}

@MainActor
func getBoolFieldWithLabel(label: String, isOn: Binding<Bool>, labelWidth: CGFloat = 120) -> some View {
    HStack {
        Text(label).frame(width: labelWidth, alignment: .trailing)
        Toggle("", isOn: isOn).frame(alignment: .leading)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .frame(alignment: .leading)
        Spacer()
    }
}
