//
//  Item.swift
//  V2rayU
//
//  Created by yanue on 2024/8/7.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
