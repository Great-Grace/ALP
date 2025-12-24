// IntroView - 앱 시작 화면
// 데이터 로딩 중 표시되는 스플래시 화면

import SwiftUI

struct IntroView: View {
    @Binding var isLoading: Bool
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8
    
    var body: some View {
        ZStack {
            // Background
            #if os(macOS)
            Color(hex: "1A1A2E")
            #else
            Color(hex: "2D2D2D")
            #endif
            
            VStack(spacing: 24) {
                // Arabic Title
                Text("كَلِمَات")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                // Subtitle
                Text("Kalimat")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(8)
                
                // Loading Indicator
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                        .padding(.top, 32)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1
                scale = 1
            }
        }
    }
}

#Preview {
    IntroView(isLoading: .constant(true))
}
