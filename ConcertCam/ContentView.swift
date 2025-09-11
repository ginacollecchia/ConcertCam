import SwiftUI
import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var photoLibraryPermissionGranted = false
    @Published var lastCapturedImage: UIImage?
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDevice: AVCaptureDevice?
    
    override init() {
        super.init()
        checkPermissions()
        setupCamera()
    }
    
    func checkPermissions() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    if granted {
                        self.setupCamera()
                    }
                }
            }
        default:
            permissionGranted = false
        }
        
        // Check photo library permission
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            photoLibraryPermissionGranted = true
            loadLastPhotoFromLibrary()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.photoLibraryPermissionGranted = (status == .authorized || status == .limited)
                    if self.photoLibraryPermissionGranted {
                        self.loadLastPhotoFromLibrary()
                    }
                }
            }
        default:
            photoLibraryPermissionGranted = false
        }
    }
    
    func setupCamera() {
        guard permissionGranted else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }
        
        self.videoDevice = videoDevice
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        self.photoOutput = photoOutput
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Add video output
        let videoOutput = AVCaptureMovieFileOutput()
        self.videoOutput = videoOutput
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        guard permissionGranted else { return }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
        }
    }
    
    func takePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        // Set auto-focus and auto-exposure to center
        setFocusAndExposureToCenter()
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func startVideoRecording() {
        guard let videoOutput = videoOutput, !videoOutput.isRecording else { return }
        
        // Set auto-focus and auto-exposure to center
        setFocusAndExposureToCenter()
        
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("concertcam_video_\(Date().timeIntervalSince1970).mov")
        
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopVideoRecording() {
        guard let videoOutput = videoOutput, videoOutput.isRecording else { return }
        videoOutput.stopRecording()
        isRecording = false
    }
    
    private func setFocusAndExposureToCenter() {
        guard let device = videoDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Set focus to center point (0.5, 0.5)
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .autoFocus
            }
            
            // Set exposure to center point
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus and exposure: \(error)")
        }
    }
    
    func loadLastPhotoFromLibrary() {
        guard photoLibraryPermissionGranted else {
            print("Photo library permission not granted, can't load thumbnail")
            return
        }
        
        print("Loading last photo from library...")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if let lastAsset = fetchResult.firstObject {
            print("Found last photo asset, requesting image...")
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .highQualityFormat
            
            imageManager.requestImage(for: lastAsset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: requestOptions) { image, _ in
                DispatchQueue.main.async {
                    if let image = image {
                        print("Successfully loaded thumbnail image")
                        self.lastCapturedImage = image
                    } else {
                        print("Failed to load thumbnail image")
                    }
                }
            }
        } else {
            print("No photos found in library")
        }
    }
    
    private func saveToPhotoLibrary(imageData: Data? = nil, videoURL: URL? = nil) {
        guard photoLibraryPermissionGranted else {
            print("Photo library permission not granted")
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            if let imageData = imageData {
                PHAssetCreationRequest.creationRequestForAsset(from: UIImage(data: imageData)!)
            } else if let videoURL = videoURL {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Media saved to Photo Library successfully")
                    // Update thumbnail with latest captured image
                    if let imageData = imageData {
                        self.lastCapturedImage = UIImage(data: imageData)
                    } else if let videoURL = videoURL {
                        self.generateVideoThumbnail(from: videoURL)
                    }
                } else if let error = error {
                    print("Error saving to Photo Library: \(error)")
                }
                
                // Clean up temporary file for video
                if let videoURL = videoURL {
                    try? FileManager.default.removeItem(at: videoURL)
                }
            }
        }
    }
    
    private func generateVideoThumbnail(from url: URL) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            DispatchQueue.main.async {
                self.lastCapturedImage = UIImage(cgImage: cgImage)
            }
        } catch {
            print("Error generating video thumbnail: \(error)")
        }
    }
}

// MARK: - Photo Capture Delegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error getting photo data")
            return
        }
        
        print("Photo captured successfully")
        saveToPhotoLibrary(imageData: imageData)
    }
}

// MARK: - Video Recording Delegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error)")
        } else {
            print("Video recorded successfully")
            saveToPhotoLibrary(videoURL: outputFileURL)
        }
    }
}

struct ContentView: View {
    @State private var showWelcome = true
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Persistent black background
            Color.black
                .ignoresSafeArea()
            
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
}

struct WelcomeScreen: View {
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Centered dark purple text with fade animation
            Text("ConcertCam")
                .font(.custom("GillSans-UltraBold", size: 48))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .opacity(textOpacity)
                .onAppear {
                    // Fade in animation
                    withAnimation(.easeInOut(duration: 1.0)) {
                        textOpacity = 1.0
                    }
                    
                    // Fade out animation after 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            textOpacity = 0.0
                        }
                    }
                }
        }
    }
}

struct MainScreen: View {
    @Binding var showSettings: Bool
    @StateObject private var cameraManager = CameraManager()
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
                    // Settings button
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSettings = true
                            }
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Main buttons
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
                    
                    Spacer()
                    
                    // Photo Library Preview (bottom left)
                    HStack {
                        PhotoLibraryPreview(lastImage: cameraManager.lastCapturedImage)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            } else if currentView == .countdown {
                CountdownView()
            } else if currentView == .blackScreen {
                BlackScreenView()
            }
        }
        .onAppear {
            cameraManager.startSession()
            // Refresh thumbnail when view appears
            if cameraManager.photoLibraryPermissionGranted {
                cameraManager.loadLastPhotoFromLibrary()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Photo Library Preview
    func PhotoLibraryPreview(lastImage: UIImage?) -> some View {
        Button(action: {
            self.openPhotosApp()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                if let image = lastImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
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
            
            // Recording indicator for video mode
            if captureMode == .video && cameraManager.isRecording {
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(0.8)
                        Text("REC")
                            .font(.caption)
                            .foregroundColor(.red)
                            .opacity(0.8)
                        Spacer()
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                    Spacer()
                }
            }
            
            // Capture indicator
            Text(captureMode == .photo ? "📸" : "🎥")
                .font(.system(size: 40))
                .opacity(0.3)
        }
        .onAppear {
            if captureMode == .photo {
                // Photo mode: Take photo and auto-return after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cameraManager.takePhoto()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentView = .main
                    }
                }
            } else if captureMode == .video {
                // Video mode: Start recording
                cameraManager.startVideoRecording()
            }
        }
        .onTapGesture {
            if captureMode == .video {
                // Video mode: Stop recording and return to main
                cameraManager.stopVideoRecording()
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
