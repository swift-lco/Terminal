import Surface

extension TerminalScrollableDocument {
    /// Applies vertical navigation in rows. Horizontal commands are not handled.
    @discardableResult
    public mutating func apply(
        _ command: SurfaceIntent.Navigation
    ) -> Bool {
        switch command {
        case .first:
            let changed = viewport.offset != 0
            moveToStart()
            return changed

        case .last:
            let changed = viewport.offset != viewport.maximumOffset
            moveToEnd()
            return changed

        case .position(let row):
            let previousOffset = viewport.offset
            moveToStart()
            let target = min(
                max(0, row),
                viewport.maximumOffset
            )
            if target > 0 {
                scrollDown(
                    by: target
                )
            }
            return viewport.offset != previousOffset

        case .horizontal:
            return false

        case .vertical,
             .page,
             .halfPage:
            guard let steps = command.verticalSteps(
                pageRows: viewport.visibleRows
            ) else {
                return false
            }

            let bounded = SurfaceIntent.Navigation.bounded(
                steps,
                to: lines.count
            )

            if bounded < 0 {
                return scrollUp(
                    by: -bounded
                )
            }

            if bounded > 0 {
                return scrollDown(
                    by: bounded
                )
            }

            return false
        }
    }
}
