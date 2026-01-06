import Foundation
import Network

/// Scant het lokale netwerk naar bonnenprinters
@MainActor
class NetworkScanner: ObservableObject {
    @Published var foundPrinters: [DiscoveredPrinter] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    
    private var scanTask: Task<Void, Never>?
    
    struct DiscoveredPrinter: Identifiable, Hashable, Sendable {
        let id = UUID()
        let ipAddress: String
        let port: UInt16
        let responseTime: TimeInterval
        
        var displayName: String {
            "Printer op \(ipAddress)"
        }
    }
    
    /// Start scanning voor printers op het netwerk
    func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        foundPrinters = []
        scanProgress = 0
        
        scanTask = Task {
            await scanNetwork()
            self.isScanning = false
            self.scanProgress = 1.0
        }
    }
    
    /// Stop de huidige scan
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }
    
    private func scanNetwork() async {
        // Haal lokaal IP subnet op
        guard let localIP = getLocalIP(),
              let subnet = getSubnet(from: localIP) else {
            return
        }
        
        // Scan alle IPs in het subnet (1-254)
        let totalIPs = 254
        var scannedCount = 0
        
        // Scan in batches voor snelheid
        let batchSize = 20
        for batchStart in stride(from: 1, through: totalIPs, by: batchSize) {
            let batchEnd = min(batchStart + batchSize - 1, totalIPs)
            
            await withTaskGroup(of: DiscoveredPrinter?.self) { group in
                for i in batchStart...batchEnd {
                    let ip = "\(subnet).\(i)"
                    group.addTask {
                        await Self.checkPrinter(at: ip, port: 9100)
                    }
                }
                
                for await result in group {
                    scannedCount += 1
                    self.scanProgress = Double(scannedCount) / Double(totalIPs)
                    
                    if let printer = result {
                        self.foundPrinters.append(printer)
                    }
                }
            }
            
            // Check of scan gecancelled is
            if Task.isCancelled { break }
        }
    }
    
    nonisolated private static func checkPrinter(at ip: String, port: UInt16) async -> DiscoveredPrinter? {
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(integerLiteral: port)
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)
            
            let resumed = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
            resumed.initialize(to: false)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !resumed.pointee {
                        resumed.pointee = true
                        let responseTime = Date().timeIntervalSince(startTime)
                        connection.cancel()
                        continuation.resume(returning: DiscoveredPrinter(
                            ipAddress: ip,
                            port: port,
                            responseTime: responseTime
                        ))
                    }
                case .failed(_), .cancelled:
                    if !resumed.pointee {
                        resumed.pointee = true
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout na 1 seconde
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if !resumed.pointee {
                    resumed.pointee = true
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    nonisolated private func getLocalIP() -> String? {
        var address: String?
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
    
    nonisolated private func getSubnet(from ip: String) -> String? {
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return nil }
        return "\(components[0]).\(components[1]).\(components[2])"
    }
}
