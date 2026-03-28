//
//  ExportView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ExportView: View {
    let items: [ProfileEntity]
    @State private var exportText: String = ""
    @State private var copied: Bool = false
    @State private var saved: Bool = false
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                LocalizedTextLabelView(label: .Export)
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button(action: onClose) {
                    LocalizedTextLabelView(label: .Close)
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(String(localized: .Total)) \(items.count) \(String(localized: .Servers))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }

                TextEditor(text: $exportText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding()

            Divider()

            HStack(spacing: 16) {
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? String(localized: .Copied) : String(localized: .Copy))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .disabled(copied)

                Button(action: saveToFile) {
                    HStack {
                        Image(systemName: saved ? "checkmark" : "square.and.arrow.down")
                        Text(saved ? String(localized: .Saved) : String(localized: .Save))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .focusable(false)
                .disabled(saved)
            }
            .padding()
        }
        .frame(width: 560, height: 400)
        .onAppear {
            generateExportText()
        }
    }

    private func generateExportText() {
        var lines: [String] = []
        for item in items {
            let uri = ShareUri.generateShareUri(item: item)
            if !uri.isEmpty {
                lines.append(uri)
            }
        }
        exportText = lines.joined(separator: "\n")
    }

    private func copyToClipboard() {
        guard !copied else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func saveToFile() {
        guard !saved else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "v2rayU_export.txt"
        savePanel.title = String(localized: .Save)
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try exportText.write(to: url, atomically: true, encoding: .utf8)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        saved = false
                    }
                } catch {
                    logger.error("Failed to save export: \(error)")
                }
            }
        }
    }
}
