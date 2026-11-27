import DSL
import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public extension RenderCapabilities {
    /// A terminal assumed to have basic colour and no OSC 8 links: safe for
    /// output that may be piped or replayed. Use `terminal(environment:isTerminal:)`
    /// for what the current terminal supports.
    static var terminal: Self {
        .init(
            hyperlinks: false,
            images: false,
            tables: true,
            colorDepth: .basic,
            interactivity: false
        )
    }

    /// What this process's terminal supports, from its environment and
    /// whether standard output is a terminal.
    static var currentTerminal: Self {
        terminal(
            environment: ProcessInfo.processInfo.environment,
            isTerminal: isatty(STDOUT_FILENO) != 0
        )
    }

    /// What the terminal named by `environment` supports. Not a terminal
    /// (piped, redirected): no colour and no links. `NO_COLOR` turns colour
    /// off; `FORCE_HYPERLINK=1` or `0` overrides link detection.
    static func terminal(
        environment: [String: String],
        isTerminal: Bool
    ) -> Self {
        var capabilities = Self.terminal
        let term = environment["TERM"] ?? ""

        guard isTerminal,
              term != "dumb"
        else {
            capabilities.colorDepth = .none
            return capabilities
        }

        capabilities.colorDepth = colorDepth(
            environment: environment,
            term: term
        )
        capabilities.hyperlinks = hyperlinks(
            environment: environment,
            term: term
        )
        return capabilities
    }
}

private extension RenderCapabilities {
    static func colorDepth(
        environment: [String: String],
        term: String
    ) -> ColorDepth {
        if let noColor = environment["NO_COLOR"],
           !noColor.isEmpty
        {
            return .none
        }

        switch environment["COLORTERM"]?.lowercased() {
        case "truecolor",
             "24bit":
            return .trueColor
        default:
            break
        }

        return term.contains("256color") ? .indexed : .basic
    }

    static let hyperlinkPrograms: Set<String> = [
        "iTerm.app",
        "WezTerm",
        "ghostty",
        "vscode",
        "rio",
    ]

    static func hyperlinks(
        environment: [String: String],
        term: String
    ) -> Bool {
        switch environment["FORCE_HYPERLINK"] {
        case "1":
            return true
        case "0":
            return false
        default:
            break
        }

        if let program = environment["TERM_PROGRAM"],
           hyperlinkPrograms.contains(program)
        {
            return true
        }

        if term.contains("kitty")
            || term.contains("ghostty")
            || environment["KITTY_WINDOW_ID"] != nil
            || environment["WT_SESSION"] != nil
            || environment["KONSOLE_VERSION"] != nil
        {
            return true
        }

        if let vte = environment["VTE_VERSION"].flatMap(Int.init) {
            return vte >= 5000
        }

        return false
    }
}
