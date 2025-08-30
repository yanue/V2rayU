//
//  Common.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

// 公共的 getTextField 函数，接受 name 和绑定的文本
@MainActor
func getTextField(name: LanguageLabel, text: Binding<String>) -> some View {
    TextField(String(localized: name), text: text)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.leading, 8)
}

// 公共的 getTextField 函数，接受 name
@MainActor
func getTextLabel(label: LanguageLabel, labelWidth: CGFloat = 100) -> some View {
    Text(String(localized: label)).frame(width: labelWidth, alignment: .trailing)
}

@MainActor
func getTextFieldWithLabel(label: LanguageLabel, text: Binding<String>, labelWidth: CGFloat = 100) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()
        TextField(String(localized: label), text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.leading, 7)
    }
}

@MainActor
func getNumFieldWithLabel(label: LanguageLabel, num: Binding<Int>, labelWidth: CGFloat = 100) -> some View {
        HStack {
            LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
            Spacer()
            TextField(String(localized: label), value: num, formatter: NumberFormatter())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.leading, 7)
        }
}

@MainActor
func getPickerWithLabel<T: CaseIterable & RawRepresentable & Hashable>(label: LanguageLabel, selection: Binding<T>,ignore: [T] = [], labelWidth: CGFloat = 100) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()
        Picker("", selection: selection) {
            ForEach(T.allCases.filter { !ignore.contains($0) }, id: \.self) { pick in
                Text(pick.rawValue)
            }
        }
        .pickerStyle(MenuPickerStyle())  // 可以根据需要修改样式
    }
}

@MainActor
func getBoolFieldWithLabel(label: LanguageLabel, isOn: Binding<Bool>, labelWidth: CGFloat = 100) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Toggle("", isOn: isOn).frame(alignment: .leading)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .frame(alignment: .leading)
        Spacer()
    }
}


@MainActor
func getTextEditorWithLabel(label: LanguageLabel, text: Binding<String>, labelWidth: CGFloat = 100) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()

        TextEditor(text: text)
            .frame(height: 60)
            .background(Color(NSColor.textBackgroundColor))
            .padding(.all, 4)
            .border(Color(NSColor.separatorColor), width: 1)
            .cornerRadius(4)
            .padding(.leading, 7)
            // 设置行间距
            .lineSpacing(4)
    }
}
