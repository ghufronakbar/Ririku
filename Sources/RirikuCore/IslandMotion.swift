import Foundation
import CoreGraphics

public enum IslandMotion {
    public static func frame(from start: CGRect, to target: CGRect, progress: Double) -> CGRect {
        let fraction = min(1, max(0, progress))
        let eased = fraction * fraction * (3 - 2 * fraction)
        let width = start.width + (target.width - start.width) * eased
        let height = start.height + (target.height - start.height) * eased
        let center = start.midX + (target.midX - start.midX) * eased
        return CGRect(x: center - width / 2, y: target.maxY - height, width: width, height: height)
    }
}
