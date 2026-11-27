import Primitives
import Terminal
import Testing

private func document(
    rows: Int,
    visible: Int
) -> TerminalScrollableDocument {
    TerminalScrollableDocument(
        lines: (0..<rows).map { "line \($0)" },
        visibleRows: visible
    )
}

private func tree() -> TerminalTreeList<String> {
    func leaf(_ id: String) -> Tree<TerminalTreeListItem<String>>.Node {
        .init(TerminalTreeListItem(id: id, title: id))
    }
    return TerminalTreeList(
        tree: Tree(roots: [
            .init(
                TerminalTreeListItem(id: "a", title: "a"),
                children: [leaf("a1"), leaf("a2")]
            ),
            leaf("b"),
            leaf("c"),
        ])
    )
}

enum NavigationCommandTests {
    static let suite = TestSuite("terminal navigation commands") {
        Test("document scrolls by rows and pages, bounded") { _ in
            var doc = document(rows: 100, visible: 10)
            try Expect.true(doc.apply(.vertical(5)), "5j")
            try Expect.equal(doc.viewport.offset, 5, "offset 5")
            doc.apply(.halfPage(2))
            try Expect.equal(doc.viewport.offset, 15, "2 ctrl-d")
            doc.apply(.page(-1))
            try Expect.equal(doc.viewport.offset, 6, "ctrl-b")
            doc.apply(.vertical(Int.max))
            try Expect.equal(doc.viewport.offset, 90, "huge j clamps")
            try Expect.true(doc.isFollowingEnd, "at end follows")
            doc.apply(.position(40))
            try Expect.equal(doc.viewport.offset, 40, "position")
            doc.apply(.first)
            try Expect.equal(doc.viewport.offset, 0, "gg")
            try Expect.false(doc.apply(.horizontal(1)), "horizontal ignored")
        }

        Test("tree moves over visible rows and repeats h/l") { _ in
            var list = tree()
            try Expect.equal(list.rows.map(\.item.id), ["a", "a1", "a2", "b", "c"], "expanded rows")
            list.apply(.vertical(3), pageRows: 10)
            try Expect.equal(list.cursor, "b", "3j")
            list.apply(.vertical(99), pageRows: 10)
            try Expect.equal(list.cursor, "c", "clamped")
            list.apply(.position(1), pageRows: 10)
            try Expect.equal(list.cursor, "a1", "position")
            list.apply(.horizontal(-5), pageRows: 10)
            try Expect.equal(list.cursor, "a", "h to parent then collapse")
            try Expect.equal(list.rows.map(\.item.id), ["a", "b", "c"], "collapsed")
            list.apply(.horizontal(2), pageRows: 10)
            try Expect.equal(list.cursor, "a1", "2l expands then enters")
        }

        Test("tree pages by the rows it last rendered") { _ in
            var list = tree()
            var frame = TerminalFrame(rows: 3, columns: 20)
            list.render(into: &frame, in: TerminalRegion(rows: 3, columns: 20))
            try Expect.equal(list.visibleRows, 3, "rendered rows")
            list.apply(.page(1))
            try Expect.equal(list.cursor, "a2", "one page is rows - 1")
        }
    }
}
