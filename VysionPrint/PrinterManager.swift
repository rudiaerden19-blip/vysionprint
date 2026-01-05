import Foundation
import Network

class PrinterManager: ObservableObject {
    @Published var printerIP: String = ""
    @Published var isConnected: Bool = false
    
    private let printerPort: UInt16 = 9100
    private let userDefaultsKey = "vysion_printer_ip"
    
    init() {
        load()
    }
    
    func save() {
        UserDefaults.standard.set(printerIP, forKey: userDefaultsKey)
    }
    
    func load() {
        printerIP = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
    }
    
    // MARK: - Printer Communication
    
    func sendData(_ data: Data) async -> Bool {
        guard !printerIP.isEmpty else { return false }
        
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(printerIP)
            let port = NWEndpoint.Port(integerLiteral: printerPort)
            let connection = NWConnection(host: host, port: port, using: .tcp)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if error == nil {
                            connection.cancel()
                            continuation.resume(returning: true)
                        } else {
                            connection.cancel()
                            continuation.resume(returning: false)
                        }
                    })
                case .failed(_):
                    connection.cancel()
                    continuation.resume(returning: false)
                case .cancelled:
                    break
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if connection.state != .cancelled {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func sendTestPrint() async -> Bool {
        var commands = Data()
        commands.append(ESCPOSCommands.initialize)
        commands.append(ESCPOSCommands.alignCenter)
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        commands.append("TEST PRINT\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        commands.append("Vysion Print App\n".data(using: .ascii) ?? Data())
        commands.append("Printer: \(printerIP)\n".data(using: .ascii) ?? Data())
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        commands.append("Als je dit ziet,\n".data(using: .ascii) ?? Data())
        commands.append("werkt alles!\n".data(using: .ascii) ?? Data())
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "nl_NL")
        commands.append("\(formatter.string(from: Date()))\n".data(using: .ascii) ?? Data())
        
        commands.append("\n\n\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.cutPaper)
        
        return await sendData(commands)
    }
    
    func openCashDrawer() async -> Bool {
        var commands = Data()
        commands.append(ESCPOSCommands.initialize)
        commands.append(ESCPOSCommands.openDrawer)
        return await sendData(commands)
    }
    
    func printReceipt(order: [String: Any], businessInfo: [String: Any]) async -> Bool {
        var commands = Data()
        
        // Initialize
        commands.append(ESCPOSCommands.initialize)
        
        // Header - bedrijfsnaam
        commands.append(ESCPOSCommands.alignCenter)
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        let businessName = businessInfo["name"] as? String ?? "Vysion Horeca"
        commands.append("\(businessName)\n".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        
        // Adres
        if let address = businessInfo["address"] as? String {
            commands.append("\(address)\n".data(using: .utf8) ?? Data())
        }
        if let city = businessInfo["city"] as? String {
            let postalCode = businessInfo["postalCode"] as? String ?? ""
            commands.append("\(postalCode) \(city)\n".data(using: .utf8) ?? Data())
        }
        if let phone = businessInfo["phone"] as? String {
            commands.append("Tel: \(phone)\n".data(using: .utf8) ?? Data())
        }
        
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        
        // Order type
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        let orderType = order["orderType"] as? String ?? "TAKEAWAY"
        let orderTypeLabel: String
        switch orderType {
        case "DINE_IN": orderTypeLabel = "TER PLAATSE"
        case "TAKEAWAY": orderTypeLabel = "AFHALEN"
        case "DELIVERY": orderTypeLabel = "BEZORGEN"
        default: orderTypeLabel = "BESTELLING"
        }
        commands.append("\(orderTypeLabel)\n".data(using: .utf8) ?? Data())
        
        if let tableNumber = order["tableNumber"] as? String, !tableNumber.isEmpty {
            commands.append("TAFEL \(tableNumber)\n".data(using: .utf8) ?? Data())
        }
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        
        // Order info
        commands.append(ESCPOSCommands.alignLeft)
        let orderNumber = order["orderNumber"] as? Int ?? 0
        commands.append("Bon #\(orderNumber)\n".data(using: .utf8) ?? Data())
        
        if let staffName = order["staffName"] as? String {
            commands.append("Bediend door: \(staffName)\n".data(using: .utf8) ?? Data())
        }
        
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        
        // Items
        if let items = order["items"] as? [[String: Any]] {
            for item in items {
                let quantity = item["quantity"] as? Int ?? 1
                let menuItem = item["menuItem"] as? [String: Any]
                let name = menuItem?["name"] as? String ?? item["name"] as? String ?? "Item"
                let price = item["totalPrice"] as? Double ?? 0
                
                let line = "\(quantity)x \(name)"
                let priceStr = String(format: "€%.2f", price)
                let padding = max(1, 32 - line.count - priceStr.count)
                commands.append("\(line)\(String(repeating: " ", count: padding))\(priceStr)\n".data(using: .utf8) ?? Data())
                
                // Options
                if let options = item["selectedOptions"] as? [[String: Any]] {
                    for opt in options {
                        if let optName = opt["optionName"] as? String {
                            commands.append("  + \(optName)\n".data(using: .utf8) ?? Data())
                        }
                    }
                }
            }
        }
        
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        
        // Totals
        let subtotal = order["subtotal"] as? Double ?? 0
        let tax = order["tax"] as? Double ?? 0
        let total = order["total"] as? Double ?? 0
        
        commands.append("Subtotaal".padding(toLength: 24, withPad: " ", startingAt: 0).data(using: .utf8) ?? Data())
        commands.append(String(format: "€%.2f\n", subtotal).data(using: .utf8) ?? Data())
        
        commands.append("BTW".padding(toLength: 24, withPad: " ", startingAt: 0).data(using: .utf8) ?? Data())
        commands.append(String(format: "€%.2f\n", tax).data(using: .utf8) ?? Data())
        
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        
        // Totaal
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        commands.append("TOTAAL".padding(toLength: 12, withPad: " ", startingAt: 0).data(using: .utf8) ?? Data())
        commands.append(String(format: "€%.2f\n", total).data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        
        // Payment
        commands.append(ESCPOSCommands.alignCenter)
        let paymentMethod = order["paymentMethod"] as? String ?? "CASH"
        let paymentLabel: String
        switch paymentMethod {
        case "CASH": paymentLabel = "Contant"
        case "CARD": paymentLabel = "PIN/Kaart"
        case "IDEAL": paymentLabel = "iDEAL"
        case "BANCONTACT": paymentLabel = "Bancontact"
        default: paymentLabel = paymentMethod
        }
        commands.append("Betaald: \(paymentLabel)\n".data(using: .utf8) ?? Data())
        
        // Footer
        commands.append("--------------------------------\n".data(using: .ascii) ?? Data())
        if let vatNumber = businessInfo["vatNumber"] as? String {
            commands.append("BTW: \(vatNumber)\n".data(using: .utf8) ?? Data())
        }
        commands.append("\nBedankt voor uw bezoek!\n".data(using: .utf8) ?? Data())
        
        // Cut
        commands.append("\n\n\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.cutPaper)
        
        return await sendData(commands)
    }
}
