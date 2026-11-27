import DSL
import Terminal
import TerminalStructuredContent

enum TerminalStructuredContentSmoke {
    enum Failure: Error {
        case wordWrapping
        case collectionSpacing
        case inlineStyles
        case recursion
        case rolePresentation
        case leakedRole
        case width
        case table
        case hyperlink
        case linkFallback
        case readerBlocks
        case capabilities
        case themeParity
        case themeColors
        case themeRoles
        case notes
    }

    static func run() throws {
        try wrapping()
        try collectionSpacing()
        try inlineStyles()
        try recursion()
        try roles()
        try width()
        try table()
        try hyperlinks()
        try readerBlocks()
        try capabilities()
        try theme()
        try notes()
        print(sample())
    }

    private static func wrapping() throws {
        let rows = TerminalStructuredContent.Renderer().rows(
            .paragraph([.text("alpha beta gamma")]),
            columns: 10
        ).map(stripANSI)

        guard rows == ["alpha beta", "gamma"] else {
            throw Failure.wordWrapping
        }
    }

    private static func collectionSpacing() throws {
        var format = TerminalStructuredContent.Format.minimal
        format.block.collection.spacing = 2

        let rows = TerminalStructuredContent.Renderer(
            format: format
        ).rows(
            .collection([
                .paragraph([.text("first")]),
                .paragraph([.text("second")]),
            ]),
            columns: 20
        ).map(stripANSI)

        guard rows == [
            "first",
            "",
            "",
            "second",
        ] else {
            throw Failure.collectionSpacing
        }
    }

    private static func inlineStyles() throws {
        let row = TerminalStructuredContent.Renderer().rows(
            .paragraph([
                .text("Use "),
                .strong([.text("strong")]),
                .text(", "),
                .emphasis([.text("emphasis")]),
                .text(", and "),
                .code("code"),
                .text(".")
            ]),
            columns: 80
        ).first ?? ""

        guard stripANSI(row) == "Use strong, emphasis, and code.",
              row.contains(TerminalStyle.bold.apply("strong")),
              row.contains(TerminalStyle(.italic).apply("emphasis")),
              row.contains(TerminalStyle.dim.apply("code")) else {
            throw Failure.inlineStyles
        }
    }

    private static func recursion() throws {
        let quote = TerminalStructuredContent.Renderer().rows(
            .quote(
                .collection([
                    .paragraph([.text("quoted")]),
                    .code(language: "swift", source: "let value = 1")
                ])
            ),
            columns: 30
        )

        guard quote.count >= 4,
              quote.allSatisfy({ stripANSI($0).hasPrefix("│ ") }) else {
            throw Failure.recursion
        }

        let list = TerminalStructuredContent.Renderer().rows(
            .list(
                style: .ordered,
                items: [
                    .paragraph([.text("first")]),
                    .collection([
                        .paragraph([.text("second")]),
                        .list(
                            style: .unordered,
                            items: [.paragraph([.text("nested")])]
                        )
                    ])
                ]
            ),
            columns: 30
        ).map(stripANSI)

        guard list.first?.hasPrefix("1. first") == true,
              list.contains(where: { $0.hasPrefix("2. second") }),
              list.contains(where: { $0.contains("• nested") }) else {
            throw Failure.recursion
        }
    }

    private static func roles() throws {
        let role = StructuredContent.Role(rawValue: "test.example")
        var format = TerminalStructuredContent.Format.minimal
        format.block.group.roles.resolve = { candidate in
            candidate == role
                ? .init(titlePrefix: "Example", contentIndent: 2)
                : nil
        }

        let renderer = TerminalStructuredContent.Renderer(format: format)
        let rows = renderer.rows(
            .group(
                role: role,
                title: [.text("Nested API")],
                content: .paragraph([.text("body")])
            ),
            columns: 40
        ).map(stripANSI)

        guard rows.first == "Example: Nested API",
              rows.last == "  body" else {
            throw Failure.rolePresentation
        }

        let unknown = StructuredContent.Role(rawValue: "unknown.role")
        let fallback = renderer.render(
            .group(
                role: unknown,
                title: [.text("Fallback")],
                content: .paragraph([.text("body")])
            ),
            columns: 40
        )

        guard !fallback.contains(unknown.rawValue) else {
            throw Failure.leakedRole
        }
    }

    private static func table() throws {
        func cell(_ text: String) -> StructuredContent { .paragraph([.text(text)]) }
        let table: StructuredContent = .table(
            header: [cell("Tool"), cell("Bytes")],
            rows: [
                [cell("mutate_files"), cell("3022")],
                [cell("read_file"), cell("640 bytes after core projection")],
            ]
        )
        let renderer = TerminalStructuredContent.Renderer()

        let aligned = renderer.rows(table, columns: 80).map(stripANSI)
        guard aligned == [
            "Tool         │ Bytes",
            String(repeating: "─", count: 13) + "┼" + String(repeating: "─", count: 32),
            "mutate_files │ 3022",
            "read_file    │ 640 bytes after core projection",
        ] else {
            throw Failure.table
        }

        let wrapped = renderer.rows(table, columns: 30).map(stripANSI)
        guard wrapped.allSatisfy({ TerminalDisplay.width(of: $0) <= 30 }),
              wrapped.count > aligned.count,
              wrapped.filter({ $0.contains("┼") }).count == 2 else {
            throw Failure.table
        }

        let fields = renderer.rows(table, columns: 12).map(stripANSI)
        guard fields.allSatisfy({ TerminalDisplay.width(of: $0) <= 12 }),
              fields.first == "Tool:",
              !fields.contains(where: { $0.contains("│") }) else {
            throw Failure.table
        }
    }

    private static func hyperlinks() throws {
        let page = StructuredContent.PageKey(rawValue: "guide")
        let content = StructuredContent.paragraph([
            .text("See "),
            .link(target: .page(page, anchor: nil), content: [.text("the guide")]),
        ])
        var capabilities = RenderCapabilities.terminal
        capabilities.hyperlinks = true
        let linked = TerminalStructuredContent.Renderer(
            capabilities: capabilities,
            resolver: StructuredContentURLTable(pages: [page: "https://example.com/guide"])
        ).rows(content, columns: 40)

        guard linked.count == 1,
              linked[0].contains("\u{001B}]8;;https://example.com/guide\u{0007}"),
              TerminalDisplay.width(of: linked[0]) == "See the guide".count
        else {
            throw Failure.hyperlink
        }

        let fallback = TerminalStructuredContent.Renderer().rows(
            .paragraph([.link(target: .external("https://example.com"), content: [.text("site")])]),
            columns: 40
        ).map(stripANSI)
        let unresolved = TerminalStructuredContent.Renderer().rows(content, columns: 40).map(stripANSI)

        guard fallback == ["site (https://example.com)"],
              unresolved == ["See the guide"]
        else {
            throw Failure.linkFallback
        }
    }

    private static func readerBlocks() throws {
        let rows = TerminalStructuredContent.Renderer().rows(
            .collection([
                .quote(.paragraph([.text("Attention is prayer.")]), attribution: [.text("Simone Weil")]),
                .verse([[.text("first line")], [.text("    indented")]]),
                .rule,
                .figure(anchor: nil, content: .image(source: .asset(.init(rawValue: "x")), alt: "A dog"), caption: [.text("Fig")]),
            ]),
            columns: 20
        ).map(stripANSI)

        guard rows == [
            "│ Attention is",
            "│ prayer.",
            "│ — Simone Weil",
            "",
            "first line",
            "    indented",
            "",
            "       * * *",
            "",
            "A dog",
            "Fig",
        ] else {
            print(rows)
            throw Failure.readerBlocks
        }
    }

    private static func capabilities() throws {
        let piped = RenderCapabilities.terminal(environment: ["TERM_PROGRAM": "ghostty"], isTerminal: false)
        let ghostty = RenderCapabilities.terminal(
            environment: ["TERM_PROGRAM": "ghostty", "COLORTERM": "truecolor"],
            isTerminal: true
        )
        let apple = RenderCapabilities.terminal(
            environment: ["TERM_PROGRAM": "Apple_Terminal", "TERM": "xterm-256color", "NO_COLOR": "1"],
            isTerminal: true
        )
        let forced = RenderCapabilities.terminal(environment: ["FORCE_HYPERLINK": "1"], isTerminal: true)

        guard !piped.hyperlinks, piped.colorDepth == .none,
              ghostty.hyperlinks, ghostty.colorDepth == .trueColor,
              !apple.hyperlinks, apple.colorDepth == .none,
              forced.hyperlinks, forced.colorDepth == .basic
        else {
            throw Failure.capabilities
        }
    }

    private static func width() throws {
        let rows = TerminalStructuredContent.Renderer().rows(
            sampleContent(),
            columns: 32
        )

        guard rows.allSatisfy({ TerminalDisplay.width(of: $0) <= 32 }) else {
            throw Failure.width
        }
    }

    private static func notes() throws {
        let resolved = StructuredContentEnumerations.resolve(
            .collection([
                .prose("Claim \(cite: .init(rawValue: "ader2019"), at: .init(.page, "12")).\(note: "A note.")"),
            ])
        )
        let rows = TerminalStructuredContent.Renderer().rows(resolved.content, columns: 30).map(stripANSI)

        guard rows == [
            "Claim [1].[2]",
            "",
            "[2] A note.",
            "",
            "[1] ader2019",
            "    p. 12 [1]",
        ] else {
            print(rows)
            throw Failure.notes
        }
    }

    private static func theme() throws {
        let content = StructuredContent.collection([
            sampleContent(),
            .heading(level: 1, anchor: nil, content: [.text("Heading")]),
            .quote(.paragraph([.text("Quoted")]), attribution: [.text("Someone")]),
            .figure(anchor: nil, content: .paragraph([.text("Body")]), caption: [.text("Caption")]),
            .rule,
            .paragraph([.link(target: .external("https://example.com"), content: [.text("site")])]),
        ])
        let minimal = TerminalStructuredContent.Renderer().render(content, columns: 48)
        let themed = TerminalStructuredContent.Renderer(
            format: .init(theme: .standard, scheme: .light, colorDepth: .basic)
        ).render(content, columns: 48)

        guard minimal == themed else {
            throw Failure.themeParity
        }

        let red = ThemeColor(css: "#ff0000")!
        let grey = ThemeColor(css: "rgb(128 128 128)")!

        guard red.basic == 9,
              red.indexed == 196,
              grey.indexed == 244,
              TerminalStyle.Color(red, depth: .none) == nil,
              TerminalStyle.Color(red, depth: .indexed) == .indexed(196),
              TerminalStyle(.init(foreground: red), colorDepth: .basic).apply("x") == "\u{001B}[91mx\u{001B}[0m",
              TerminalStyle(.init(foreground: red), colorDepth: .indexed).apply("x") == "\u{001B}[38;5;196mx\u{001B}[0m"
        else {
            throw Failure.themeColors
        }

        var theme = Theme.standard
        theme.light[.note] = .init(foreground: ThemeColor(css: "#0a63c9"), indent: 2)
        theme.dark[.note] = .init(foreground: ThemeColor(css: "#7ab8ff"))
        let light = TerminalStructuredContent.Format(theme: theme, scheme: .light, colorDepth: .trueColor)
        let dark = TerminalStructuredContent.Format(theme: theme, scheme: .dark, colorDepth: .trueColor)
        let note = StructuredContent.group(role: .note, title: [.text("Note")], content: .paragraph([.text("Body")]))
        let lightRows = TerminalStructuredContent.Renderer(format: light).rows(note, columns: 20)
        let darkRows = TerminalStructuredContent.Renderer(format: dark).rows(note, columns: 20)

        guard lightRows.map(stripANSI) == ["Note", "", "  Body"],
              lightRows[0].contains("38;2;10;99;201"),
              darkRows[0].contains("38;2;122;184;255"),
              lightRows[0].contains("\u{001B}[1m")
        else {
            print(lightRows, darkRows)
            throw Failure.themeRoles
        }
    }

    private static func sample() -> String {
        var format = TerminalStructuredContent.Format.minimal
        format.block.group.roles["test.example"] = .init(
            titlePrefix: "Example",
            contentIndent: 2
        )

        return TerminalStructuredContent.Renderer(format: format).render(
            sampleContent(),
            columns: 64
        )
    }

    private static func sampleContent() -> StructuredContent {
        .collection([
            .group(
                role: nil,
                title: [.text("Structured content")],
                content: .paragraph([
                    .text("A sparse terminal projection with "),
                    .strong([.text("strong")]),
                    .text(", "),
                    .emphasis([.text("emphasis")]),
                    .text(", and "),
                    .code("inline code"),
                    .text(".")
                ])
            ),
            .quote(
                .paragraph([.text("Quotes remain recursive and visually quiet.")])
            ),
            .list(
                style: .unordered,
                items: [
                    .paragraph([.text("Lists accept complete structured-content items.")]),
                    .group(
                        role: "test.example",
                        title: [.text("Role formatting")],
                        content: .paragraph([
                            .text("Consumers can specialize semantic roles without teaching Terminal the domain.")
                        ])
                    )
                ]
            ),
            .code(
                language: "swift",
                source:
                    "let format = TerminalStructuredContent.Format.minimal\n"
                    + "let renderer = TerminalStructuredContent.Renderer(format: format)"
            )
        ])
    }
}
