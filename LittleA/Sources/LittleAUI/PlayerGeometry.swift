import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

struct PlayerViewport {
    let sceneSize: CGSize
    let bounds: CGRect

    var scale: CGFloat {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return 0 }
        return min(bounds.width / sceneSize.width, bounds.height / sceneSize.height)
    }

    var contentRect: CGRect {
        let size = CGSize(width: sceneSize.width * scale, height: sceneSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    func scenePoint(_ point: CGPoint) -> CGPoint {
        guard scale > 0 else { return .zero }
        return CGPoint(x: (point.x - contentRect.minX) / scale,
                       y: (point.y - contentRect.minY) / scale)
    }

    func viewRect(_ rect: CGRect) -> CGRect {
        CGRect(x: contentRect.minX + rect.minX * scale, y: contentRect.minY + rect.minY * scale,
               width: rect.width * scale, height: rect.height * scale)
    }
}

struct PlayerClock {
    let fps: Double
    private var previous: Double?
    private var remainder = 0.0

    init(fps: Double) {
        precondition(fps.isFinite && fps > 0)
        self.fps = fps
    }

    mutating func reset() {
        previous = nil
        remainder = 0
    }

    mutating func steps(at timestamp: Double) -> Int {
        defer { previous = timestamp }
        guard let previous else { return 0 }
        remainder += min(max(timestamp - previous, 0), 0.25)
        let available = floor(remainder * fps + 1e-9)
        let count = Int(min(available, 8))
        remainder = available > 8 ? 0 : max(0, remainder - Double(count) / fps)
        return count
    }
}