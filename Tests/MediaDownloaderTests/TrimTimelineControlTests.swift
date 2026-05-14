@testable import MediaDownloader
import AppKit
import XCTest

final class TrimTimelineControlTests: XCTestCase {
    func testClickingStartHandlePreviewsWithoutMovingSelection() {
        let control = makeControl()
        var changes: [(TrimSelection, Double)] = []
        control.selectionDidChange = { selection, previewTime in
            changes.append((selection, previewTime))
        }

        let handlePoint = startHandlePoint(for: control).offsetBy(dx: 6, dy: 0)
        control.mouseDown(with: mouseEvent(type: .leftMouseDown, at: handlePoint))
        control.mouseUp(with: mouseEvent(type: .leftMouseUp, at: handlePoint))

        XCTAssertEqual(control.selection, TrimSelection(start: 10, end: 40))
        XCTAssertEqual(control.playheadTime, 10, accuracy: 0.001)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.0, TrimSelection(start: 10, end: 40))
        XCTAssertEqual(changes.first?.1 ?? -1, 10, accuracy: 0.001)
    }

    func testDraggingStartHandleMovesAfterDragThresholdAndPreservesGrabOffset() {
        let control = makeControl()
        var latestSelection = control.selection
        control.selectionDidChange = { selection, _ in
            latestSelection = selection
        }

        let handlePoint = startHandlePoint(for: control).offsetBy(dx: 6, dy: 0)
        control.mouseDown(with: mouseEvent(type: .leftMouseDown, at: handlePoint))
        control.mouseDragged(with: mouseEvent(type: .leftMouseDragged, at: handlePoint.offsetBy(dx: 20, dy: 0)))
        control.mouseUp(with: mouseEvent(type: .leftMouseUp, at: handlePoint.offsetBy(dx: 20, dy: 0)))

        XCTAssertEqual(latestSelection.start, 10 + 20 / timelineWidth * control.duration, accuracy: 0.01)
        XCTAssertEqual(latestSelection.end, 40, accuracy: 0.001)
        XCTAssertEqual(control.selection, latestSelection)
    }

    private var timelineWidth: CGFloat {
        639
    }

    private func makeControl() -> TrimTimelineControl {
        let control = TrimTimelineControl(frame: NSRect(x: 0, y: 0, width: 640, height: 60))
        control.duration = 100
        control.selection = TrimSelection(start: 10, end: 40)
        control.playheadTime = 10
        return control
    }

    private func startHandlePoint(for control: TrimTimelineControl) -> CGPoint {
        CGPoint(
            x: 0.5 + timelineWidth * CGFloat(control.selection.start / control.duration),
            y: control.bounds.midY
        )
    }

    private func mouseEvent(type: NSEvent.EventType, at point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }
}

private extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}
