import SwiftUI

/// FirstLaunchView - Shown when app is not yet activated
/// Shows "Kassa wordt klaargezet..." during install
/// Or asks for activation code if needed
struct FirstLaunchView: View {
    @EnvironmentObject var installManager: InstallManager
    @EnvironmentObject var printerManager: PrinterManager
    @EnvironmentObject var printServer: PrintServer
    
    @State private var activationCode: String = ""
    @State private var showManualEntry = false
    @State private var isCheckingClipboard = true
    @State private var devTapCount = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.24, green: 0.30, blue: 0.42),
                    Color(red: 0.15, green: 0.20, blue: 0.30)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo - tap 5x voor development mode
                Image(systemName: "cart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .onTapGesture {
                        devTapCount += 1
                        if devTapCount >= 5 {
                            // Activate as Frituur Nolim (development mode)
                            installManager.markAsLegacyFrituurNolim()
                        }
                    }
                
                Text("Vysion Kassa")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if installManager.isInstalling {
                    // Installing state
                    installingView
                } else if let error = installManager.installError {
                    // Error state
                    errorView(error: error)
                } else if showManualEntry {
                    // Manual code entry
                    manualEntryView
                } else {
                    // Initial state - checking for token
                    checkingView
                }
                
                Spacer()
                
                // Footer
                Text("© 2025 Vysion Horeca")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)
            }
            .padding()
        }
        .onAppear {
            checkForInstallToken()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }
    
    // MARK: - Installing View
    
    private var installingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Kassa wordt klaargezet…")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Even geduld")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(40)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
    
    // MARK: - Checking View
    
    private var checkingView: some View {
        VStack(spacing: 20) {
            if isCheckingClipboard {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Even geduld...")
                    .font(.headline)
                    .foregroundColor(.white)
            } else {
                Text("Welkom!")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("Open de installatie link die je hebt ontvangen na registratie.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: { showManualEntry = true }) {
                    Text("Handmatig invoeren")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                Button(action: { activateDemo() }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Demo Modus")
                    }
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Manual Entry View
    
    private var manualEntryView: some View {
        VStack(spacing: 20) {
            Text("Voer je activatiecode in")
                .font(.title2)
                .foregroundColor(.white)
            
            TextField("", text: $activationCode)
                .placeholder(when: activationCode.isEmpty) {
                    Text("Plak hier je code...")
                        .foregroundColor(.white.opacity(0.5))
                }
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .padding(.horizontal, 40)
            
            Button(action: activateWithCode) {
                Text("Activeren")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.24, green: 0.30, blue: 0.42))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .disabled(activationCode.isEmpty)
            .padding(.horizontal, 40)
            
            Button(action: { showManualEntry = false }) {
                Text("Annuleren")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(error)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                installManager.installError = nil
                showManualEntry = true
            }) {
                Text("Probeer opnieuw")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.24, green: 0.30, blue: 0.42))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Actions
    
    private func checkForInstallToken() {
        // Check clipboard for token (iOS might have copied from URL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let clipboardText = UIPasteboard.general.string,
               clipboardText.contains("eyJ") { // JWT tokens start with eyJ
                // Found a potential token
                activationCode = clipboardText
                activateWithCode()
            } else {
                isCheckingClipboard = false
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle install URL: vysionprint://install?token=XXX
        // Or: https://appvysion.com/install?token=XXX
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            return
        }
        
        activationCode = token
        activateWithCode()
    }
    
    private func activateWithCode() {
        guard !activationCode.isEmpty else { return }
        
        Task {
            let success = await installManager.runInstallFlow(token: activationCode)
            if success {
                // Start printer auto-setup in background
                Task {
                    await PrinterManager.shared.autoSetup()
                }
            }
        }
    }
    
    private func activateDemo() {
        // Activate demo mode (same as legacy Frituur Nolim)
        installManager.markAsLegacyFrituurNolim()
    }
}

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    FirstLaunchView()
        .environmentObject(InstallManager.shared)
        .environmentObject(PrinterManager())
        .environmentObject(PrintServer())
}
