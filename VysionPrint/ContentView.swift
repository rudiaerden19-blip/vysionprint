import SwiftUI

struct ContentView: View {
    @EnvironmentObject var printerManager: PrinterManager
    @EnvironmentObject var printServer: PrintServer
    @StateObject private var scanner = NetworkScanner()
    
    @State private var manualIP: String = ""
    @State private var manualPort: String = "9100"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showManualEntry = false
    @State private var showKassa = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Server Status
                    serverStatusSection
                    
                    // Huidige printer
                    if !printerManager.printerIP.isEmpty {
                        currentPrinterSection
                    }
                    
                    // Scanner sectie
                    scannerSection
                    
                    // Handmatige invoer
                    manualEntrySection
                    
                    // Test knoppen
                    if !printerManager.printerIP.isEmpty {
                        testButtonsSection
                    }
                    
                    // Statistieken
                    statsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .alert("Melding", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            manualIP = printerManager.printerIP
            manualPort = String(printerManager.printerPort)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "printer.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.24, green: 0.30, blue: 0.42)) // #3C4D6B
            
            Text("Vysion Print")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Bonnenprinter voor Vysion Horeca")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Open Kassa knop
            if !printerManager.printerIP.isEmpty {
                Button(action: { showKassa = true }) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Open Kassa")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.24, green: 0.30, blue: 0.42))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.top, 12)
            }
        }
        .padding(.top, 20)
        .fullScreenCover(isPresented: $showKassa) {
            NavigationView {
                KassaView()
                    .environmentObject(printServer)
            }
        }
    }
    
    // MARK: - Server Status
    
    private var serverStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(printServer.isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(printServer.isRunning ? "Server actief" : "Server gestopt")
                    .font(.headline)
                
                Spacer()
            }
            
            if printServer.isRunning {
                HStack {
                    Text("http://\(getLocalIP()):3001")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = "http://\(getLocalIP()):3001"
                        alertMessage = "Gekopieerd!"
                        showingAlert = true
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    // MARK: - Current Printer
    
    private var currentPrinterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verbonden printer")
                        .font(.headline)
                    Text("\(printerManager.printerIP):\(printerManager.printerPort)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    printerManager.printerIP = ""
                    printerManager.save()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            
            if let error = printerManager.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    // MARK: - Scanner
    
    private var scannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔍 Printers zoeken")
                    .font(.headline)
                
                Spacer()
                
                if scanner.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if scanner.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: scanner.scanProgress)
                        .tint(Color(red: 0.24, green: 0.30, blue: 0.42))
                    
                    Text("Scannen... \(Int(scanner.scanProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Gevonden printers
            if !scanner.foundPrinters.isEmpty {
                VStack(spacing: 8) {
                    ForEach(scanner.foundPrinters) { printer in
                        Button(action: {
                            selectPrinter(printer)
                        }) {
                            HStack {
                                Image(systemName: "printer.fill")
                                    .foregroundColor(Color(red: 0.24, green: 0.30, blue: 0.42))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Printer gevonden")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(printer.ipAddress)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            } else if !scanner.isScanning && scanner.scanProgress > 0 {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("Geen printers gevonden")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Scan knop
            Button(action: {
                if scanner.isScanning {
                    scanner.stopScan()
                } else {
                    scanner.startScan()
                }
            }) {
                HStack {
                    Image(systemName: scanner.isScanning ? "stop.fill" : "magnifyingglass")
                    Text(scanner.isScanning ? "Stop" : "Zoek printers")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.24, green: 0.30, blue: 0.42))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    // MARK: - Manual Entry
    
    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    showManualEntry.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(Color(red: 0.24, green: 0.30, blue: 0.42))
                    Text("Handmatig invoeren")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showManualEntry {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IP-adres")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("192.168.1.100", text: $manualIP)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Poort (standaard 9100)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("9100", text: $manualPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Button(action: saveManualPrinter) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Opslaan")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    // MARK: - Test Buttons
    
    private var testButtonsSection: some View {
        HStack(spacing: 16) {
            Button(action: testPrint) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title)
                    Text("Test Print")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.24, green: 0.30, blue: 0.42))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: openDrawer) {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.up")
                        .font(.title)
                    Text("Open Lade")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        VStack(spacing: 4) {
            Text("Bonnen geprint: \(printServer.printCount)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let lastPrint = printServer.lastPrintTime {
                Text("Laatste: \(lastPrint, style: .relative) geleden")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Actions
    
    private func selectPrinter(_ printer: NetworkScanner.DiscoveredPrinter) {
        printerManager.selectPrinter(ip: printer.ipAddress, port: printer.port)
        alertMessage = "Printer geselecteerd: \(printer.ipAddress)"
        showingAlert = true
    }
    
    private func saveManualPrinter() {
        let ip = manualIP.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = UInt16(manualPort) ?? 9100
        
        guard !ip.isEmpty else {
            alertMessage = "Vul een IP-adres in"
            showingAlert = true
            return
        }
        
        printerManager.selectPrinter(ip: ip, port: port)
        alertMessage = "Printer opgeslagen: \(ip):\(port)"
        showingAlert = true
        showManualEntry = false
    }
    
    private func testPrint() {
        Task {
            let success = await printerManager.sendTestPrint()
            await MainActor.run {
                alertMessage = success ? "Test print verzonden!" : "Kon niet printen. \(printerManager.lastError ?? "")"
                showingAlert = true
            }
        }
    }
    
    private func openDrawer() {
        Task {
            let success = await printerManager.openCashDrawer()
            await MainActor.run {
                alertMessage = success ? "Kassalade geopend!" : "Kon lade niet openen."
                showingAlert = true
            }
        }
    }
    
    private func getLocalIP() -> String {
        var address: String = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}

#Preview {
    ContentView()
        .environmentObject(PrinterManager())
        .environmentObject(PrintServer())
}
