import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Adaptive theme colors
    static let uniCardBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1.0)
            : UIColor.systemBackground
    })
    
    static let uniCardBorder = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.25, alpha: 0.5)
            : UIColor(white: 0.88, alpha: 0.8)
    })
    
    static let uniTodayBadge = Color.blue
    static let uniTomorrowBadge = Color.orange
    static let uniFutureBadge = Color.purple
    
    // Lesson types colors
    static let typeLecture = Color.blue
    static let typePractice = Color.orange
    static let typeLab = Color.purple
    static let typeOnline = Color.teal
    static let typeExam = Color.red
}

extension View {
    func cardStyle(isActive: Bool = false) -> some View {
        self
            .background(Color.uniCardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.accentColor : Color.uniCardBorder, lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(isActive ? 0.12 : 0.04), radius: isActive ? 8 : 4, x: 0, y: isActive ? 4 : 2)
    }
}
