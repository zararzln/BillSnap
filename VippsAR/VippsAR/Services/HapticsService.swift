import UIKit

struct HapticsService {
    func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
