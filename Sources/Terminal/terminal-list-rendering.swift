import Surface

public extension SurfaceList.Control {
    typealias RowRenderer = @Sendable (
        SurfaceList.Row<Item, ID>
    ) -> String

    func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        row: RowRenderer
    ) {
        frame.write(
            rows().map(
                row
            ),
            in: region
        )
    }
}

public extension SurfaceList.MultiSelect {
    typealias RowRenderer = @Sendable (
        SurfaceList.Row<Item, ID>
    ) -> String

    func render(
        into frame: inout TerminalFrame,
        in region: TerminalRegion,
        row: RowRenderer
    ) {
        frame.write(
            rows().map(
                row
            ),
            in: region
        )
    }
}
