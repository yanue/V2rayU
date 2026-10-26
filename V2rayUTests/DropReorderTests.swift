import Testing
@testable import V2rayU

/// 表格拖拽排序: 落点是显示列表(可能经过筛选)里的位置
struct DropReorderTests {
    private struct Row: Identifiable, Equatable {
        let id: String
    }

    private func rows(_ ids: String) -> [Row] {
        ids.map { Row(id: String($0)) }
    }

    private func ids(_ list: [Row]) -> String {
        list.map(\.id).joined()
    }

    @Test("Moving multiple rows to the end does not go out of bounds")
    func multipleRowsToEnd() {
        // 原来: 删掉 2 行后按 index-1=5 插入, 列表只剩 4 行, 越界崩溃
        let list = rows("abcdef")
        let result = reorderedAfterDrop(list, displayed: list, index: 6, moved: rows("ab"))
        #expect(ids(result) == "cdefab")
    }

    @Test(arguments: [
        ("a", 3, "bcade"),   // 往下拖
        ("d", 1, "adbce"),   // 往上拖
        ("a", 0, "abcde"),   // 原地
        ("a", 1, "abcde"),   // 落在自己下面
        ("bd", 0, "bdace"),  // 多选、不连续
        ("bd", 5, "acebd"),  // 多选拖到末尾
        ("e", 99, "abcde"),  // 越界的落点
        ("e", -1, "eabcd"),
    ])
    func moves(moved: String, index: Int, expected: String) {
        let list = rows("abcde")
        #expect(ids(reorderedAfterDrop(list, displayed: list, index: index, moved: rows(moved))) == expected)
    }

    @Test("Drop position is mapped from the filtered list")
    func filteredList() {
        let list = rows("abcdefg")
        // 只显示 c e g (如筛选了某个分组): 把 g 拖到 e 前面
        #expect(ids(reorderedAfterDrop(list, displayed: rows("ceg"), index: 1, moved: rows("g"))) == "abcdgef")
        // 拖到显示列表末尾: 放在显示的最后一个未拖动的行后面
        #expect(ids(reorderedAfterDrop(list, displayed: rows("ceg"), index: 3, moved: rows("c"))) == "abdefgc")
        #expect(ids(reorderedAfterDrop(list, displayed: rows("ce"), index: 2, moved: rows("c"))) == "abdecfg")
    }

    @Test("Rows not in the list are ignored")
    func foreignRows() {
        let list = rows("abc")
        #expect(ids(reorderedAfterDrop(list, displayed: list, index: 1, moved: rows("xy"))) == "abc")
        #expect(ids(reorderedAfterDrop(list, displayed: list, index: 0, moved: rows("xc"))) == "cab")
        #expect(reorderedAfterDrop([Row](), displayed: [], index: 3, moved: rows("a")).isEmpty)
    }
}
