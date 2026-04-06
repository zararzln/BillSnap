import SwiftUI

enum VippsLocale { case norway, denmark }

/// Constructs Vipps and MobilePay deep-link payment URLs.
///
/// Spec: https://developer.vippsmobilepay.com/docs/APIs/vipps-deeplink-api/
///
/// Both apps expect the amount in the smallest currency unit (øre/ører):
///   149.50 NOK → "14950"
struct VippsDeepLinkService {

    let locale: VippsLocale

    // MARK: - Public

    var appName: String {
        locale == .norway ? "Vipps" : "MobilePay"
    }

    var brandColor: Color {
        // Vipps orange vs MobilePay blue
        locale == .norway
            ? Color(red: 1.0,  green: 0.55, blue: 0.0)
            : Color(red: 0.25, green: 0.47, blue: 0.85)
    }

    var isAppInstalled: Bool {
        guard let url = URL(string: locale == .norway ? "vipps://" : "mobilepay://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Builds the deep-link URL for a payment request.
    ///
    /// - Parameters:
    ///   - amount:    Amount in the local currency (NOK / DKK), as a `Decimal`.
    ///   - recipient: Phone number of the receiver. Digits only; country code stripped automatically.
    ///   - message:   Short description shown in the payment app.
    func paymentURL(amount: Decimal, recipient: String, message: String) -> URL? {
        switch locale {
        case .norway:  return vippsURL(amount: amount, recipient: recipient, message: message)
        case .denmark: return mobilepayURL(amount: amount, recipient: recipient, message: message)
        }
    }

    // MARK: - URL builders

    /// `vipps://payment?amount=&recipient=&message=`
    private func vippsURL(amount: Decimal, recipient: String, message: String) -> URL? {
        var c = URLComponents()
        c.scheme = "vipps"
        c.host   = "payment"
        c.queryItems = [
            .init(name: "amount",    value: øreString(amount)),
            .init(name: "recipient", value: sanitized(recipient)),
            .init(name: "message",   value: message)
        ]
        return c.url
    }

    /// `mobilepay://send?amount=&to=&comment=`
    private func mobilepayURL(amount: Decimal, recipient: String, message: String) -> URL? {
        var c = URLComponents()
        c.scheme = "mobilepay"
        c.host   = "send"
        c.queryItems = [
            .init(name: "amount",  value: øreString(amount)),
            .init(name: "to",      value: sanitized(recipient)),
            .init(name: "comment", value: message)
        ]
        return c.url
    }

    // MARK: - Formatting

    private func øreString(_ amount: Decimal) -> String {
        let øre = (amount * 100) as NSDecimalNumber
        return "\(øre.intValue)"
    }

    private func sanitized(_ phone: String) -> String {
        var digits = phone.filter(\.isNumber)
        // Strip leading country code (+47 / +45) if present
        if digits.count > 8 { digits = String(digits.suffix(8)) }
        return digits
    }

    // MARK: - Static helper for start screen

    static func appNameForLocale() -> String {
        Locale.current.region?.identifier == "DK" ? "MobilePay" : "Vipps"
    }
}
