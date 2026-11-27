import ANSI

public struct TerminalStyle: Sendable, Hashable {
    public enum Color: Sendable, Hashable {
        case rgb(
            red: UInt8,
            green: UInt8,
            blue: UInt8
        )
        /// A colour of the xterm 256-colour palette.
        case indexed(UInt8)
        /// One of the 16 standard colours: 0–7 normal, 8–15 bright.
        case basic(UInt8)

        public static func hex(
            _ value: String
        ) -> Self? {
            let value = value.hasPrefix("#")
                ? String(
                    value.dropFirst()
                )
                : value

            guard value.count == 6,
                  let rgb = UInt32(
                    value,
                    radix: 16
                  )
            else {
                return nil
            }

            return .rgb(
                red: UInt8(
                    (rgb >> 16) & 0xff
                ),
                green: UInt8(
                    (rgb >> 8) & 0xff
                ),
                blue: UInt8(
                    rgb & 0xff
                )
            )
        }

        /// `#rrggbb` for an RGB colour; palette colours depend on the
        /// terminal's palette and have none.
        public func hex() -> String? {
            switch self {
            case .indexed,
                 .basic:
                return nil

            case .rgb(
                let red,
                let green,
                let blue
            ):
                return "#"
                    + Self.hexComponent(
                        red
                    )
                    + Self.hexComponent(
                        green
                    )
                    + Self.hexComponent(
                        blue
                    )
            }
        }

        fileprivate func ansiSequence(
            background: Bool
        ) -> String {
            switch self {
            case .rgb(
                let red,
                let green,
                let blue
            ):
                return ANSIColor.rgb(
                    Int(red),
                    Int(green),
                    Int(blue),
                    background
                )

            case .indexed(let index):
                return "\u{001B}[\(background ? 48 : 38);5;\(index)m"

            case .basic(let index):
                let index = Int(min(15, index))
                let base = index < 8
                    ? (background ? 40 : 30)
                    : (background ? 100 : 90)
                return "\u{001B}[\(base + index % 8)m"
            }
        }

        private static func hexComponent(
            _ value: UInt8
        ) -> String {
            let component = String(
                value,
                radix: 16,
                uppercase: false
            )

            return component.count == 1
                ? "0" + component
                : component
        }
    }

    private enum Component: Sendable, Hashable {
        case ansi(ANSIColor)
        case foreground(Color)
        case background(Color)

        var ansiSequence: String {
            switch self {
            case .ansi(let code):
                return code.rawValue

            case .foreground(let color):
                return color.ansiSequence(
                    background: false
                )

            case .background(let color):
                return color.ansiSequence(
                    background: true
                )
            }
        }
    }

    private var components: [Component]

    /// An OSC 8 hyperlink target. Terminals without OSC 8 show the text
    /// alone, so set it only where the target supports links.
    public var hyperlink: String?

    public var codes: [ANSIColor] {
        get {
            components.compactMap { component in
                guard case .ansi(let code) = component else {
                    return nil
                }

                return code
            }
        }
        set {
            let colors = components.filter { component in
                switch component {
                case .ansi:
                    return false

                case .foreground,
                     .background:
                    return true
                }
            }

            components = newValue.map {
                .ansi(
                    $0
                )
            } + colors
        }
    }

    public var isEmpty: Bool {
        components.isEmpty
            && hyperlink == nil
    }

    public init(
        _ codes: ANSIColor...
    ) {
        self.components = codes.map {
            .ansi(
                $0
            )
        }
    }

    public init(
        codes: [ANSIColor]
    ) {
        self.components = codes.map {
            .ansi(
                $0
            )
        }
    }

    public init(
        foreground: Color?,
        background: Color?,
        codes: [ANSIColor] = []
    ) {
        var components = codes.map {
            Component.ansi(
                $0
            )
        }

        if let foreground {
            components.append(
                .foreground(
                    foreground
                )
            )
        }

        if let background {
            components.append(
                .background(
                    background
                )
            )
        }

        self.components = components
    }

    public func merging(
        _ overlay: TerminalStyle
    ) -> TerminalStyle {
        TerminalStyle(
            components:
                components
                + overlay.components,
            hyperlink:
                overlay.hyperlink
                ?? hyperlink
        )
    }

    public func apply(
        _ text: String
    ) -> String {
        let styled: String

        if components.isEmpty {
            styled = text
        } else {
            let prefix = components
                .map(\.ansiSequence)
                .joined()

            styled = "\(prefix)\(text)\(ANSIColor.reset.rawValue)"
        }

        guard let hyperlink else {
            return styled
        }

        return ANSILink.osc8(
            url: hyperlink,
            label: styled
        )
    }

    public static func link(
        _ url: String
    ) -> TerminalStyle {
        var style = TerminalStyle()
        style.hyperlink = url
        return style
    }

    public func apply(
        lines: [String]
    ) -> [String] {
        lines.map {
            apply($0)
        }
    }

    public static let none = TerminalStyle()
    public static let bold = TerminalStyle(.bold)
    public static let dim = TerminalStyle(.dim)
}

private extension TerminalStyle {
    private init(
        components: [Component],
        hyperlink: String?
    ) {
        self.components = components
        self.hyperlink = hyperlink
    }
}
