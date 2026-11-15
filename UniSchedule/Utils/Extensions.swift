import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    
    // Liquid Glass accent tokens (Android 3.0 parity)
    static let uniLiveEmerald = Color(hex: "#10B981")
    static let uniNextSky = Color(hex: "#38BDF8")
    static let uniWindowAmber = Color(hex: "#F59E0B")
    static let uniAmber = Color(hex: "#F59E0B")
    static let uniPurple = Color(hex: "#8B5CF6")
    static let uniRose = Color(hex: "#F43F5E")
    
    // Adaptive Liquid Glass surface & stroke tokens
    static let uniGlassSurface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.15, blue: 0.25, alpha: 0.56)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.62)
    })
    
    static let uniGlassSurfaceStrong = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.16, blue: 0.28, alpha: 0.78)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.84)
    })
    
    static let uniGlassSurfaceFallback = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.13, blue: 0.20, alpha: 0.96)
            : UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 0.96)
    })
    
    static let uniGlassCapsule = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.21, blue: 0.34, alpha: 0.64)
            : UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 0.74)
    })
    
    static let uniGlassStrokeStart = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.34)
            : UIColor(white: 1.0, alpha: 0.90)
    })
    
    static let uniGlassStrokeMid = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.12)
            : UIColor(red: 0.76, green: 0.84, blue: 0.96, alpha: 0.45)
    })
    
    static let uniGlassStrokeEnd = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.62, blue: 0.95, alpha: 0.22)
            : UIColor(red: 0.68, green: 0.78, blue: 0.94, alpha: 0.38)
    })
    
    // Adaptive Liquid Glass backdrop tokens
    static let uniBackdropBase = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)
            : UIColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1.0)
    })
    
    static let uniBackdropBlob1 = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.25, blue: 0.56, alpha: 0.52)
            : UIColor(red: 0.62, green: 0.78, blue: 1.0, alpha: 0.42)
    })
    
    static let uniBackdropBlob2 = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.26, green: 0.18, blue: 0.54, alpha: 0.44)
            : UIColor(red: 0.76, green: 0.70, blue: 1.0, alpha: 0.34)
    })
    
    static let uniBackdropBlob3 = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.36, blue: 0.50, alpha: 0.40)
            : UIColor(red: 0.56, green: 0.88, blue: 0.96, alpha: 0.36)
    })
    
    static let uniBackdropBlobWarm = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.45, blue: 0.34, alpha: 0.42)
            : UIColor(red: 0.52, green: 0.90, blue: 0.74, alpha: 0.32)
    })
    
    // Lesson types colors
    static let typeLecture = Color.blue
    static let typePractice = Color.orange
    static let typeLab = Color.purple
    static let typeOnline = Color.teal
    static let typeExam = Color.red
    
    static func lessonTypeColor(for type: String) -> Color {
        UniSchedule.lessonTypeColor(for: type)
    }
}

public func lessonTypeColor(for type: String) -> Color {
    switch type {
    case Constants.lessonTypeLecture, Constants.lessonTypeOnlineLecture:
        return Color(hex: "#3B82F6")
    case Constants.lessonTypePractice:
        return .uniPurple
    case Constants.lessonTypeOnlinePractice:
        return .uniLiveEmerald
    case Constants.lessonTypeLab:
        return .uniAmber
    case Constants.lessonTypeExam:
        return .uniRose
    default:
        return .secondary
    }
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
