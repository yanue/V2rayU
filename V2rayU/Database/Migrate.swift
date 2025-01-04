//
//  Migrate.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import GRDB

/// 协议：模型负责其表的迁移注册
protocol DatabaseMigratable {
    /// 注册该模型的迁移到 DatabaseMigrator
    static func registerMigrations(in migrator: inout DatabaseMigrator)
}

extension AppDatabase {
    // 迁移
    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
      
        // 注册所有模型的迁移逻辑
        ProfileModel.registerMigrations(in: &migrator)
        ProfileStatModel.registerMigrations(in: &migrator)
        SubModel.registerMigrations(in: &migrator)
        RoutingModel.registerMigrations(in: &migrator)
        
        return migrator
    }
}
