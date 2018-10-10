//
//  Server.swift
//  V2rayU
//
//  Created by yanue on 2018/10/10.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
class ConfigServer: NSObject {
    var tableViewData = [["remark":"hk"],["remark":"us"]]
   
    func list() -> [Dictionary<String, String>] {
        return tableViewData
    }
    
    func count() -> Int {
       return tableViewData.count
    }
    
    func add() -> [Dictionary<String, String>] {
        self.tableViewData.append(["remark":"new server"])
        return self.tableViewData
    }

    func remove(idx: Int) -> [Dictionary<String, String>] {
        guard idx >= 0 && idx < tableViewData.count else {
            print("Index out of bounds while deleting item at index \(index) in \(self). This action is ignored.")
            return tableViewData
        }
        // delete from tmp
        tableViewData.remove(at: idx)
        // todo delete file
        return tableViewData
    }
    
}
