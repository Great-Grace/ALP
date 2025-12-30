// DesignSystem - 트렌디한 디자인 시스템
// Gen Z Style Color Palette & Components
// Updated with Premium Glassmorphism & Mesh Gradients

import SwiftUI

// MARK: - Color Palette
extension Color {
    // Primary Colors - Vivid & Deep
    static let primary = Color(hex: "6C5CE7")      // Vivid Purple
    static let primaryDark = Color(hex: "4834D4")  // Deep Purple
    static let primaryLight = Color(hex: "A29BFE") // Light Purple
    
    // Accent Colors - Pop & Fresh
    static let accent = Color(hex: "00B894")       // Mint Green
    static let accentDark = Color(hex: "008F72")   // Deep Mint
    static let accentPink = Color(hex: "FD79A8")   // Soft Pink
    
    // Backgrounds - Clean & Glassy
    static let backgroundPrimary = Color(hex: "FAFAFA")   // Pure Off-white
    static let backgroundSecondary = Color.white          // Pure White
    
    // Text - Sharp & Readable
    static let textPrimary = Color(hex: "2D3436")     // Almost Black
    static let textSecondary = Color(hex: "636E72")   // Dark Grey
    static let textTertiary = Color(hex: "B2BEC3")    // Light Grey
    
    // Semantic
    static let success = Color(hex: "00B894")    // Mint Green for Success
    static let error = Color(hex: "FF7675")      // Soft Red for Error
    static let warning = Color(hex: "FDCB6E")    // Warm Yellow for Warning
    

    
    // Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
}

// MARK: - App Font System
struct AppFont {
    // English & Numbers (System Font)
    static func title1() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
    static func title2() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func title3() -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func headline() -> Font { .system(size: 19, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 17, weight: .regular, design: .default) }
    static func minicaps() -> Font { .system(size: 12, weight: .bold, design: .default).smallCaps() }
    
    // MARK: - Arabic Custom Font (Amiri)
    // 1.3x larger than Korean/English for visual balance
    
    /// 아랍어 대제목 (퀴즈 카드 메인)
    static func arabicLarge() -> Font {
        .custom("Amiri-Bold", size: 44)  // 34 * 1.3
    }
    
    /// 아랍어 제목
    static func arabicTitle() -> Font {
        .custom("Amiri-Bold", size: 36)  // 28 * 1.3
    }
    
    /// 아랍어 본문
    static func arabicBody() -> Font {
        .custom("Amiri-Regular", size: 28)  // 22 * 1.3
    }
    
    /// 아랍어 예문
    static func arabicSentence() -> Font {
        .custom("Amiri-Regular", size: 24)  // 18 * 1.3
    }
    
    /// 아랍어 버튼/선택지
    static func arabicButton() -> Font {
        .custom("Amiri-Regular", size: 22)  // 17 * 1.3
    }
    
    /// 아랍어 캡션
    static func arabicCaption() -> Font {
        .custom("Amiri-Regular", size: 18)  // 14 * 1.3
    }
}

// MARK: - Design Constants
struct Design {
    // Corner Radius
    static let radiusSmall: CGFloat = 12
    static let radiusMedium: CGFloat = 20
    static let radiusLarge: CGFloat = 32
    static let radiusPill: CGFloat = 999
    
    // Shadows - Premium & Soft
    static let shadowSofter = Shadow(color: .black.opacity(0.03), radius: 10, y: 5)
    static let shadowSoft = Shadow(color: .black.opacity(0.07), radius: 20, y: 10)
    static let shadowFloat = Shadow(color: .primary.opacity(0.2), radius: 30, y: 15)
    static let shadowInner = Shadow(color: .black.opacity(0.1), radius: 2, y: 2) // For inset effect
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }
    
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    
    // Animation
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let easeInOut = Animation.easeInOut(duration: 0.2)
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color.primary, Color.primaryLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let meshGradient = LinearGradient(
        colors: [
            Color(hex: "6C5CE7"),
            Color(hex: "A29BFE"),
            Color(hex: "74B9FF")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers

/// Glassmorphism Card Style
struct GlassyCardStyle: ViewModifier {
    var padding: CGFloat = Design.spacingL
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial) // Native glass material
            .background(Color.white.opacity(0.4)) // White tint
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Design.shadowSoft.color, radius: Design.shadowSoft.radius, y: Design.shadowSoft.y)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.5), lineWidth: 1) // Glass border
            )
    }
}

extension View {
    func glassyCard(padding: CGFloat = Design.spacingL, cornerRadius: CGFloat = Design.radiusLarge) -> some View {
        modifier(GlassyCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
    
    func cardStyle(padding: CGFloat = Design.spacingL) -> some View {
        self
            .padding(padding)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Design.radiusLarge))
            .shadow(color: Design.shadowSoft.color, radius: Design.shadowSoft.radius, y: Design.shadowSoft.y)
    }
    
    func appFont(_ font: Font) -> some View {
        self.font(font)
    }
    
    func scaleOnPress() -> some View {
        self.buttonStyle(ScaleButtonStyle())
    }
}

// Alias for compatibility
typealias PrimaryButtonStyle = PremiumButtonStyle

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Design.springBouncy, value: configuration.isPressed)
    }
}

// MARK: - Premium Button Styles

/// 3D Premium Button
struct PremiumButtonStyle: ButtonStyle {
    var color: Color = .primary
    var isFullWidth: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline())
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 18)
            .padding(.horizontal, isFullWidth ? 0 : 32)
            .background(
                ZStack {
                    // Base Layer
                    RoundedRectangle(cornerRadius: Design.radiusPill)
                        .fill(color)
                    
                    // Gradient Overlay for 3D feel
                    RoundedRectangle(cornerRadius: Design.radiusPill)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear, .black.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .shadow(color: color.opacity(0.3), radius: 15, y: 10)
            .shadow(color: color.opacity(0.2), radius: 5, y: 2) // Harder shadow
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Design.springBouncy, value: configuration.isPressed)
    }
}

/// Neumorphic/Soft Button
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline())
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Design.radiusPill))
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: Design.radiusPill)
                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Design.springSmooth, value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("New Design System") {
    ZStack {
        // Dynamic Background
        LinearGradient(colors: [Color.backgroundPrimary, Color(hex: "F0F3F9")], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        
        VStack(spacing: 30) {
            Text("Design System")
                .appFont(AppFont.title1())
                .foregroundStyle(Color.textPrimary)
            
            // Buttons
            Button("Get Started") {}
                .buttonStyle(PremiumButtonStyle(color: .primary))
            
            Button("Continue") {}
                .buttonStyle(PremiumButtonStyle(color: .accent))
            
            Button("Maybe Later") {}
                .buttonStyle(SoftButtonStyle())
            
            // Glass Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Glassmorphism")
                    .appFont(AppFont.title3())
                Text("This is a premium glass card with blur and subtle border.")
                    .appFont(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .glassyCard()
        }
        .padding(30)
    }
}
