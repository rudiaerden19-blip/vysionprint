import SwiftUI

@main
struct VysionPrintApp: App {
    @StateObject private var printerManager = PrinterManager.shared
    @StateObject private var printServer = PrintServer()
    @StateObject private var installManager = InstallManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(printerManager)
                .environmentObject(printServer)
                .environmentObject(installManager)
                .onAppear {
                    // Start print server wanneer app opent
                    printServer.printerManager = printerManager
                    printServer.start()
                }
        }
    }
}

/// Root view that decides what to show based on install status
struct RootView: View {
    @EnvironmentObject var installManager: InstallManager
    @EnvironmentObject var printerManager: PrinterManager
    @EnvironmentObject var printServer: PrintServer
    
    @State private var isChecking = true
    @State private var installStatus: InstallStatus = .notInstalled
    
    var body: some View {
        Group {
            if isChecking {
                // Loading screen
                ZStack {
                    Color(red: 0.24, green: 0.30, blue: 0.42)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            } else {
                switch installStatus {
                case .notInstalled:
                    // Show activation screen
                    FirstLaunchView()
                        .onChange(of: installManager.isInstalled) { newValue in
                            if newValue {
                                // Refresh status when installed
                                installStatus = installManager.checkInstallStatus()
                            }
                        }
                    
                case .installed(let config), .legacyInstalled(let config):
                    // Show kassa
                    MainKassaView(tenantConfig: config)
                }
            }
        }
        .onAppear {
            checkInstallStatus()
        }
    }
    
    private func checkInstallStatus() {
        // Small delay to show splash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            installStatus = installManager.checkInstallStatus()
            
            // BACKWARD COMPATIBILITY: Als app al werkte voor Frituur Nolim
            // en er geen keychain data is, markeer als legacy
            if case .notInstalled = installStatus {
                // Check if printer was already configured (= existing installation)
                if !printerManager.printerIP.isEmpty {
                    installManager.markAsLegacyFrituurNolim()
                    installStatus = installManager.checkInstallStatus()
                }
            }
            
            isChecking = false
        }
    }
}
