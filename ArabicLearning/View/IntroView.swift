// IntroView - 앱 시작 화면
// 데이터 로딩 진행률 표시 + 스플래시 화면

import SwiftUI
import SwiftData

struct IntroView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isLoading: Bool
    
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8
    @State private var loadingProgress: Double = 0
    @State private var loadingStatus: String = "준비 중..."
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Background
            #if os(macOS)
            Color(hex: "1A1A2E")
            #else
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            #endif
            
            VStack(spacing: 24) {
                Spacer()
                
                // Arabic Title
                Text("كَلِمَات")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                // Subtitle
                Text("Kalimat")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(8)
                
                Spacer()
                
                // Loading Section
                VStack(spacing: 16) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.2))
                                .frame(height: 8)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "4ECDC4"), Color(hex: "44B09E")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * loadingProgress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)
                    
                    // Status Text
                    Text(loadingStatus)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    
                    // Percentage
                    Text("\(Int(loadingProgress * 100))%")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 60)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .ignoresSafeArea()
        .onAppear {
            startLoading()
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }
    
    // MARK: - Loading Logic
    
    private func startLoading() {
        // Animate in
        withAnimation(.easeOut(duration: 0.8)) {
            opacity = 1
            scale = 1
        }
        
        // Start data loading
        loadingTask = Task {
            // Subscribe to loading state
            for await state in await DataLoaderService.shared.stateStream() {
                await MainActor.run {
                    updateUI(for: state)
                }
                
                // Check for completion
                if case .completed = state {
                    await completeLoading()
                    break
                } else if case .skipped = state {
                    await completeLoading()
                    break
                } else if case .failed = state {
                    await completeLoading()
                    break
                }
            }
        }
        
        // Trigger the actual loading
        Task {
            _ = await DataLoaderService.shared.loadCurriculumIfNeeded(context: modelContext)
        }
    }
    
    private func updateUI(for state: DataLoadingState) {
        switch state {
        case .idle:
            loadingStatus = "준비 중..."
            loadingProgress = 0
            
        case .loading(let progress):
            loadingProgress = progress
            if progress < 0.1 {
                loadingStatus = "데이터베이스 초기화 중..."
            } else if progress < 0.5 {
                loadingStatus = "아랍어 동사 데이터 로딩 중..."
            } else if progress < 0.95 {
                loadingStatus = "커리큘럼 구성 중..."
            } else {
                loadingStatus = "마무리 중..."
            }
            
        case .completed(let count):
            loadingProgress = 1.0
            loadingStatus = "\(count)개 단어 로드 완료!"
            
        case .skipped(let reason):
            loadingProgress = 1.0
            loadingStatus = reason
            
        case .failed(let error):
            loadingStatus = "오류: \(error)"
        }
    }
    
    @MainActor
    private func completeLoading() async {
        // Small delay to show completion
        try? await Task.sleep(for: .milliseconds(500))
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isLoading = false
        }
    }
}

#Preview {
    IntroView(isLoading: .constant(true))
}

