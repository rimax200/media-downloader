import Foundation

struct TrimSelection: Equatable {
    var start: Double
    var end: Double

    func clamped(to duration: Double) -> TrimSelection {
        guard duration > 0 else {
            return TrimSelection(start: 0, end: 0)
        }

        let safeStart = min(max(start, 0), duration)
        let safeEnd = min(max(end, safeStart + 0.25), duration)
        return TrimSelection(start: safeStart, end: safeEnd)
    }
}
