import SwiftUI

struct ContentView: View {
    @State private var showWelcome = true
    @State private var showSettings = false
    
    var body: some View {
        if showWelcome {
            WelcomeScreen()
                .onAppear {
                    // Automatically transition after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showWelcome = false
                        }
                    }
                }
        } else if showSettings {
            SettingsView(showSettings: $showSettings)
        } else {
            MainScreen(showSettings: $showSettings)
        }
    }
}

struct WelcomeScreen: View {
    var body: some View {
        ZStack {
            // Gray background
            Color.gray
                .ignoresSafeArea()
            
            // Centered white text
            Text("Welcome to ConcertCam")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct MainScreen: View {
    @Binding var showSettings: Bool
    @State private var currentView: ViewState = .main
    @State private var countdownNumber = 3
    @State private var captureMode: CaptureMode = .photo
    
    enum ViewState {
        case main
        case countdown
        case blackScreen
    }
    
    enum CaptureMode {
        case photo
        case video
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            if currentView == .main {
                VStack {
                    // Settings button (only visible on home/main screen)
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSettings = true
                            }
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Main buttons
                    MainButtons()
                    
                    Spacer()
                }
            } else if currentView == .countdown {
                CountdownView()
            } else if currentView == .blackScreen {
                BlackScreenView()
            }
        }
    }
    
    // MARK: - Main Buttons View
    func MainButtons() -> some View {
        VStack(spacing: 60) {
            // Video Button (above)
            Button(action: {
                startCapture(mode: .video)
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
            }
            
            // Photo Button (below)
            Button(action: {
                startCapture(mode: .photo)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .background(Circle().fill(Color.white.opacity(0.3)))
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Countdown View
    func CountdownView() -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            Text("\(countdownNumber)...")
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.gray)
                .scaleEffect(1.2)
                .animation(.easeInOut(duration: 0.3), value: countdownNumber)
        }
        .onAppear {
            startCountdown()
        }
    }
    
    // MARK: - Black Screen View
    func BlackScreenView() -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Optional: Add a subtle indicator that capture is happening
            Text(captureMode == .photo ? "📸" : "🎥")
                .font(.system(size: 40))
                .opacity(0.3)
        }
        .onAppear {
            if captureMode == .photo {
                // Photo mode: Return automatically after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentView = .main
                    }
                }
            }
            // Video mode: Stay on black screen until user taps
        }
        .onTapGesture {
            if captureMode == .video {
                // Video mode: Return to main on tap
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentView = .main
                }
            }
        }
    }
    
    // MARK: - Functions
    func startCapture(mode: CaptureMode) {
        captureMode = mode
        countdownNumber = 3
        withAnimation(.easeInOut(duration: 0.3)) {
            currentView = .countdown
        }
    }
    
    func startCountdown() {
        if countdownNumber > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                countdownNumber -= 1
                startCountdown()
            }
        } else {
            // Countdown finished, go to black screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentView = .blackScreen
                }
            }
        }
    }
}

struct SettingsView: View {
    @Binding var showSettings: Bool
    @State private var numberOfPhotos = 1
    @State private var intervalSeconds = 1
    @State private var exposureCompensation: Float = 0.0
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with X button
                HStack {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Settings content
                ScrollView {
                    VStack(spacing: 40) {
                        // Number of Photos
                        SettingSection(
                            title: "Number of Photos",
                            value: "\(numberOfPhotos)",
                            content: {
                                VStack {
                                    HStack {
                                        Text("1")
                                            .foregroundColor(.gray)
                                        
                                        Slider(value: Binding(
                                            get: { Double(numberOfPhotos) },
                                            set: { numberOfPhotos = Int($0) }
                                        ), in: 1...10, step: 1)
                                        .accentColor(.white)
                                        
                                        Text("10")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("Current: \(numberOfPhotos)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        )
                        
                        // Interval
                        SettingSection(
                            title: "Interval (seconds)",
                            value: "\(intervalSeconds)s",
                            content: {
                                VStack {
                                    HStack {
                                        Text("1")
                                            .foregroundColor(.gray)
                                        
                                        Slider(value: Binding(
                                            get: { Double(intervalSeconds) },
                                            set: { intervalSeconds = Int($0) }
                                        ), in: 1...10, step: 1)
                                        .accentColor(.white)
                                        
                                        Text("10")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("Current: \(intervalSeconds) second\(intervalSeconds == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        )
                        
                        // Exposure Compensation
                        SettingSection(
                            title: "Exposure Compensation",
                            value: String(format: "%.1f", exposureCompensation),
                            content: {
                                VStack {
                                    HStack {
                                        Text("-2.0")
                                            .foregroundColor(.gray)
                                        
                                        Slider(value: $exposureCompensation, in: -2.0...2.0, step: 0.1)
                                            .accentColor(.white)
                                        
                                        Text("+2.0")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("Current: \(exposureCompensation, specifier: "%.1f")")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        )
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                }
            }
        }
    }
}

struct SettingSection<Content: View>: View {
    let title: String
    let value: String
    let content: Content
    
    init(title: String, value: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
            }
            
            content
                .padding(.horizontal, 10)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 15)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
