import SwiftUI
import Observation

/// Root application container. Injected into the SwiftUI environment at launch.
/// Owns all shared services so they are created once and reused everywhere.
@Observable
final class AppContainer {

    // MARK: - Services
    let vippsService: VippsDeepLinkService
    let haptics: HapticsService
    let ocrService: MenuOCRService

    // MARK: - Navigation
    var activeSession: ARSplitSession?
    var tab: Tab = .split

    init() {
        let locale: VippsLocale = Locale.current.region?.identifier == "DK" ? .denmark : .norway
        self.vippsService  = VippsDeepLinkService(locale: locale)
        self.haptics       = HapticsService()
        self.ocrService    = MenuOCRService()
    }

    func startNewSession() {
        activeSession = ARSplitSession()
    }

    func endSession() {
        activeSession = nil
    }

    enum Tab { case split, history }
}
