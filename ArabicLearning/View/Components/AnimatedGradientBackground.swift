import SwiftUI

struct AnimatedGradientBackground: View {
    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)
    
    let colors: [Color]
    
    init(colors: [Color] = [Color.primaryLight.opacity(0.3), Color.white, Color.accent.opacity(0.2)]) {
        self.colors = colors
    }
    
    var body: some View {
        LinearGradient(colors: colors, startPoint: start, endPoint: end)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    start = UnitPoint(x: 1, y: 0)
                    end = UnitPoint(x: 0, y: 1)
                }
            }
            .blur(radius: 50) // Soft blur for mesh effect
    }
}

#Preview {
    AnimatedGradientBackground()
}
