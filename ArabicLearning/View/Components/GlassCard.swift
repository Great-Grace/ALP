import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    
    init(padding: CGFloat = Design.spacingL, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .glassyCard(padding: padding)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2)
        GlassCard {
            Text("Hello Glass")
        }
    }
}
