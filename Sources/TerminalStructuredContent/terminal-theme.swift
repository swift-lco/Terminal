import DSL
import Terminal

public extension TerminalStyle.Color {
    /// `color` at `depth`: RGB for true colour, the nearest palette colour
    /// otherwise; nil without colour.
    init?(
        _ color: ThemeColor,
        depth: RenderCapabilities.ColorDepth
    ) {
        switch depth {
        case .none:
            return nil
        case .basic:
            self = .basic(color.basic)
        case .indexed:
            self = .indexed(color.indexed)
        case .trueColor:
            self = .rgb(
                red: color.red,
                green: color.green,
                blue: color.blue
            )
        }
    }
}

public extension TerminalStyle {
    /// A theme style as SGR: bold or dim for weight, italic, underline,
    /// colours at `colorDepth`. Spacing and indentation are layout, not style.
    init(
        _ style: Theme.Style,
        colorDepth: RenderCapabilities.ColorDepth
    ) {
        var codes: [ANSIColor] = []

        switch style.weight {
        case .bold:
            codes.append(.bold)
        case .light:
            codes.append(.dim)
        case .regular,
             nil:
            break
        }

        if style.italic == true {
            codes.append(.italic)
        }

        if style.underline == true {
            codes.append(.underline)
        }

        self.init(
            foreground: style.foreground.flatMap {
                Color($0, depth: colorDepth)
            },
            background: style.background.flatMap {
                Color($0, depth: colorDepth)
            },
            codes: codes
        )
    }
}

public extension TerminalStructuredContent.Format {
    /// The roles every target styles, mapped onto the renderer's parts.
    /// Other roles in the theme become group presentations (title style,
    /// content indent, spacing).
    static let themedRoles: Set<Theme.Role> = [
        .body, .heading, .emphasis, .strong, .code, .link,
        .quote, .caption, .muted, .accent, .rule,
    ]

    init(
        theme: Theme,
        scheme: Theme.Scheme,
        colorDepth: RenderCapabilities.ColorDepth
    ) {
        func style(_ role: Theme.Role) -> TerminalStyle {
            theme.style(role, scheme: scheme).map {
                TerminalStyle($0, colorDepth: colorDepth)
            } ?? .none
        }

        var format = Self.minimal
        format.inline = .init(
            text: .none,
            code: style(.code),
            emphasis: style(.emphasis),
            strong: style(.strong),
            link: style(.link),
            noteReference: style(.muted)
        )
        format.block.paragraph.style = style(.body)
        format.block.heading.style = style(.heading)
        format.block.code.languageStyle = style(.muted)
        format.block.quote.gutter.style = style(.quote)
        format.block.quote.attributionStyle = style(.caption)
        format.block.figure.captionStyle = style(.caption)
        format.block.rule.style = style(.rule)
        format.block.table.borderStyle = style(.rule)
        format.block.list.markerStyle = style(.muted)

        if let spacing = theme.style(.body, scheme: scheme)?.spacing {
            format.block.collection.spacing = spacing
        }

        for role in theme.roles where !Self.themedRoles.contains(role) {
            guard let roleStyle = theme.style(role, scheme: scheme) else {
                continue
            }

            let title = TerminalStyle(roleStyle, colorDepth: colorDepth)
            format.block.group.roles[role] = .init(
                titleStyle: roleStyle.weight == nil ? TerminalStyle.bold.merging(title) : title,
                contentIndent: roleStyle.indent ?? 0,
                spacing: roleStyle.spacing ?? 1
            )
        }

        self = format
    }
}
