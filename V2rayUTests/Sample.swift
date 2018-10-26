//
//  Sample.swift
//  V2rayUTests
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

struct PersonProfile1: Codable {
    var desc:String = "aaa"
}

struct PersonProfile2: Codable {
    var intro:String = "aaa"
}

struct Person: Codable {
    var name: String = "bbb"
    
    var profile1:PersonProfile1?
    var profile2:PersonProfile2?
    
    enum CodingKeys: String, CodingKey {
        case name = "title"
        case setting
    }
}
extension Person {
    init(from decoder: Decoder) throws {
        
        let vals = try decoder.container(keyedBy: CodingKeys.self)
        name = try vals.decode(String.self, forKey: CodingKeys.name)
        if name == "aa" {
            try vals.decode(PersonProfile1.self, forKey: .setting)
        } else {
            try vals.decode(PersonProfile2.self, forKey: .setting)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        //        var profile = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .setting)
        //        try profile.encode(self.profile, forKey: .setting)
        if name == "aa" {
            try container.encode(self.profile1, forKey: .setting)
        } else {
            try container.encode(self.profile2, forKey: .setting)
        }
        
    }
}
