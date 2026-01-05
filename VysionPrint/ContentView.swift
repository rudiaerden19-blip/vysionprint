import SwiftUI

struct ContentView: View {
    @EnvironmentObject var printerManager: PrinterManager
    @EnvironmentObject var printServer: PrintServer
    
    @State private var printerIP: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Vysion Print")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Bonnenprinter voor Vysion Horeca")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Server Status
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(printServer.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(printServer.isRunning ? "Server actief" : "Server gestopt")
                            .font(.headline)
                    }
                    
                    if printServer.isRunning {
                        Text("http://\(getLocalIP()):3001")
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 2)
                
                // Printer configuratie
                VStack(alignment: .leading, spacing: 12) {
                    Text("Printer IP-adres")
                        .font(.headline)
                    
                    HStack {
                        TextField("192.168.1.100", text: $printerIP)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        Button(action: savePrinterIP) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !printerManager.printerIP.isEmpty {
                        HStack {
                            Image(systemName: "printer")
                            Text(printerManager.printerIP)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 2)
                
                // Test knoppen
                HStack(spacing: 16) {
                    Button(action: testPrint) {
                        VStack {
                            Image(systemName: "doc.text")
                                .font(.title)
                            Text("Test Print")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: openDrawer) {
                        VStack {
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
                
                Spacer()
                
                // Print statistieken
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
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                printerIP = printerManager.printerIP
            }
            .alert("Melding", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func savePrinterIP() {
        let ip = printerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ip.isEmpty {
            printerManager.printerIP = ip
            printerManager.save()
            alertMessage = "Printer opgeslagen: \(ip)"
            showingAlert = true
        }
    }
    
    private func testPrint() {
        if printerManager.printerIP.isEmpty {
            alertMessage = "Vul eerst een printer IP-adres in"
            showingAlert = true
            return
        }
        
        Task {
            let success = await printerManager.sendTestPrint()
            await MainActor.run {
                alertMessage = success ? "Test print verzonden!" : "Kon niet printen. Check IP-adres."
                showingAlert = true
            }
        }
    }
    
    private func openDrawer() {
        if printerManager.printerIP.isEmpty {
            alertMessage = "Vul eerst een printer IP-adres in"
            showingAlert = true
            return
        }
        
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
