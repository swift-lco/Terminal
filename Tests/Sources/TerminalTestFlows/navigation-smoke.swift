import Surface
import Terminal

enum TerminalNavigationSmoke {
    enum Failure:
        Error
    {
        case unexpectedNavigationBinding(
            String
        )
    }

    static func run() throws {
        try expect(
            .control("P"),
            .previous,
            on: .vertical
        )

        try expect(
            .control("N"),
            .next,
            on: .vertical
        )

        try expect(
            .control("P"),
            .previous,
            on: .horizontal
        )

        try expect(
            .control("N"),
            .next,
            on: .horizontal
        )

        try expect(
            .up,
            .previous,
            on: .vertical
        )

        try expect(
            .down,
            .next,
            on: .vertical
        )

        try expect(
            .char("k"),
            .previous,
            on: .vertical
        )

        try expect(
            .char("j"),
            .next,
            on: .vertical
        )

        try expect(
            .left,
            .previous,
            on: .horizontal
        )

        try expect(
            .right,
            .next,
            on: .horizontal
        )

        try expect(
            .char("h"),
            .previous,
            on: .horizontal
        )

        try expect(
            .char("l"),
            .next,
            on: .horizontal
        )

        guard SurfaceInput.Key.control("P")
                .isVerticalPrevious,
              SurfaceInput.Key.control("P")
                .isHorizontalPrevious,
              SurfaceInput.Key.control("N")
                .isVerticalNext,
              SurfaceInput.Key.control("N")
                .isHorizontalNext
        else {
            throw Failure
                .unexpectedNavigationBinding(
                    "Ctrl-P/Ctrl-N axis independence"
                )
        }

        print(
            "navigation smoke passed"
        )
    }

    private static func expect(
        _ key: SurfaceInput.Key,
        _ expected: SurfaceIntent.Navigation.Direction,
        on axis: SurfaceIntent.Navigation.Axis
    ) throws {
        guard key.navigationDirection(
            on: axis
        ) == expected else {
            throw Failure
                .unexpectedNavigationBinding(
                    "\(key) on \(axis)"
                )
        }
    }
}
