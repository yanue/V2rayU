import GRDB
import Testing
@testable import V2rayU

/// 列表批量删除: 一个事务删完 (#1674)
/// 用内存数据库, 不碰 ~/.V2rayU 里的真实数据
struct BatchDeleteTests {
    private struct MemoryProfileStore: StoreProtocol {
        typealias Entity = ProfileEntity
        let dbReader: DatabaseReader
        let dbWriter: DatabaseWriter
    }

    private func makeStore() throws -> MemoryProfileStore {
        let db = try AppDatabase(DatabaseQueue())
        return MemoryProfileStore(dbReader: db.dbWriter, dbWriter: db.dbWriter)
    }

    private func seed(_ store: MemoryProfileStore, _ uuids: [String]) throws {
        try store.dbWriter.write { db in
            for (index, uuid) in uuids.enumerated() {
                var p = ProfileEntity(uuid: uuid, remark: uuid)
                p.sort = index
                try p.insert(db)
            }
        }
    }

    @Test("Deletes only the given rows")
    func deleteSelected() throws {
        let store = try makeStore()
        try seed(store, ["a", "b", "c", "d", "e"])
        #expect(store.delete(uuids: ["b", "d", "not-exist"]))
        #expect(store.fetchAll().map(\.uuid) == ["a", "c", "e"])
    }

    @Test("Empty list is a no-op")
    func deleteEmpty() throws {
        let store = try makeStore()
        try seed(store, ["a", "b"])
        #expect(store.delete(uuids: []))
        #expect(store.fetchAll().map(\.uuid) == ["a", "b"])
    }

    @Test("Deleting every row leaves the table empty")
    func deleteAll() throws {
        let store = try makeStore()
        let uuids = (0..<200).map { "p\($0)" }
        try seed(store, uuids)
        #expect(store.delete(uuids: uuids))
        #expect(store.fetchAll().isEmpty)
    }
}
