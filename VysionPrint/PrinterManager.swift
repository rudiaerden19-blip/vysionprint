import Foundation
import Network

@MainActor
class PrinterManager: ObservableObject {
    @Published var printerIP: String = ""
    @Published var printerPort: UInt16 = 9100
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    
    private let userDefaultsKeyIP = "vysion_printer_ip"
    private let userDefaultsKeyPort = "vysion_printer_port"
    
    init() {
        load()
    }
    
    func save() {
        UserDefaults.standard.set(printerIP, forKey: userDefaultsKeyIP)
        UserDefaults.standard.set(Int(printerPort), forKey: userDefaultsKeyPort)
    }
    
    func load() {
        printerIP = UserDefaults.standard.string(forKey: userDefaultsKeyIP) ?? ""
        let savedPort = UserDefaults.standard.integer(forKey: userDefaultsKeyPort)
        printerPort = savedPort > 0 ? UInt16(savedPort) : 9100
    }
    
    func selectPrinter(ip: String, port: UInt16) {
        printerIP = ip
        printerPort = port
        save()
    }
    
    // MARK: - Printer Communication
    
    nonisolated func sendData(_ data: Data, to ip: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(integerLiteral: port)
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)
            
            let resumed = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
            resumed.initialize(to: false)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if !resumed.pointee {
                            resumed.pointee = true
                            connection.cancel()
                            continuation.resume(returning: error == nil)
                        }
                    })
                case .failed(_):
                    if !resumed.pointee {
                        resumed.pointee = true
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                case .cancelled:
                    break
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if !resumed.pointee {
                    resumed.pointee = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func sendTestPrint() async -> Bool {
        let ip = printerIP
        let port = printerPort
        
        guard !ip.isEmpty else {
            lastError = "Geen printer IP ingesteld"
            return false
        }
        
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
        commands.append("Printer: \(ip):\(port)\n".data(using: .ascii) ?? Data())
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
        
        let success = await sendData(commands, to: ip, port: port)
        if success {
            isConnected = true
            lastError = nil
        } else {
            isConnected = false
            lastError = "Verbinding mislukt"
        }
        return success
    }
    
    func openCashDrawer() async -> Bool {
        let ip = printerIP
        let port = printerPort
        
        guard !ip.isEmpty else {
            lastError = "Geen printer IP ingesteld"
            return false
        }
        
        var commands = Data()
        commands.append(ESCPOSCommands.initialize)
        commands.append(ESCPOSCommands.openDrawer)
        
        return await sendData(commands, to: ip, port: port)
    }
    
    func printReceipt(order: [String: Any], businessInfo: [String: Any]) async -> Bool {
        let ip = printerIP
        let port = printerPort
        
        guard !ip.isEmpty else {
            lastError = "Geen printer IP ingesteld"
            return false
        }
        
        var commands = Data()
        
        // Lijnbreedtes (48 karakters bij normale tekst op 80mm papier)
        let W = 42  // Werkbare breedte
        let sep = String(repeating: "-", count: 42) + "\n"
        
        // Initialize + EXTRA ZWART + meer ruimte + euro code page + beetje letter spacing
        commands.append(ESCPOSCommands.initialize)
        commands.append(ESCPOSCommands.codePagePC858)  // Voor € symbool
        commands.append(ESCPOSCommands.emphasizeOn)    // Double-strike = donkerder
        commands.append(ESCPOSCommands.boldOn)         // Bold = nog donkerder
        commands.append(ESCPOSCommands.lineSpacingWide)
        commands.append(ESCPOSCommands.charSpacingWide) // Beetje ruimte tussen letters
        
        // ==================== HEADER ====================
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.alignCenter)
        
        // Bedrijfsnaam - GROOT
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleSize)
        let businessName = businessInfo["name"] as? String ?? "Vysion Horeca"
        commands.append("\(businessName)\n".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        
        // Adres - normaal formaat
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
        commands.append(ESCPOSCommands.boldOff)
        
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(sep.data(using: .ascii) ?? Data())
        
        // ==================== ORDER TYPE ====================
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        let orderType = order["orderType"] as? String ?? "TAKEAWAY"
        let orderTypeIcon: String
        let orderTypeLabel: String
        switch orderType {
        case "DINE_IN":
            orderTypeIcon = "(Y)"  // Bord symbool
            orderTypeLabel = "HIER OPETEN"
        case "TAKEAWAY":
            orderTypeIcon = ">>"
            orderTypeLabel = "AFHALEN"
        case "DELIVERY":
            orderTypeIcon = "=>"
            orderTypeLabel = "BEZORGEN"
        default:
            orderTypeIcon = ""
            orderTypeLabel = "BESTELLING"
        }
        commands.append("\(orderTypeIcon) \(orderTypeLabel)\n".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        
        commands.append("\n".data(using: .ascii) ?? Data())
        
        // Bon nummer + datum op één regel
        commands.append(ESCPOSCommands.alignLeft)
        let orderNumber = order["orderNumber"] as? Int ?? 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yy, HH:mm"
        let dateStr = dateFormatter.string(from: Date())
        let bonText = "Bon #\(orderNumber)"
        let bonPad = max(2, W - bonText.count - dateStr.count)
        commands.append("\(bonText)\(String(repeating: " ", count: bonPad))\(dateStr)\n".data(using: .utf8) ?? Data())
        
        // Bediend door - gecentreerd
        if let staffName = order["staffName"] as? String {
            commands.append(ESCPOSCommands.alignCenter)
            commands.append("Bediend door: \(staffName)\n".data(using: .utf8) ?? Data())
        }
        
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(sep.data(using: .ascii) ?? Data())
        commands.append("\n".data(using: .ascii) ?? Data())
        
        // ==================== ITEMS ====================
        commands.append(ESCPOSCommands.alignLeft)
        
        if let items = order["items"] as? [[String: Any]] {
            for item in items {
                let quantity = item["quantity"] as? Int ?? 1
                let name = item["name"] as? String ?? "Item"
                let price = item["totalPrice"] as? Double ?? 0
                
                // Item: GROOT + BOLD
                commands.append(ESCPOSCommands.boldOn)
                commands.append(ESCPOSCommands.doubleHeight)
                
                let itemText = "\(quantity)x \(name)"
                let priceWithEuro = String(format: "E%.2f", price)  // E als placeholder voor €
                let padding = max(1, W - itemText.count - priceWithEuro.count)
                // Item naam + padding
                commands.append("\(itemText)\(String(repeating: " ", count: padding))".data(using: .utf8) ?? Data())
                // € symbool + spatie + prijs
                commands.append(ESCPOSCommands.euroSymbol)
                commands.append(String(format: " %.2f\n", price).data(using: .utf8) ?? Data())
                
                commands.append(ESCPOSCommands.normalSize)
                commands.append(ESCPOSCommands.boldOff)
                
                // Opties - normaal, ingesprongen, beetje afstand van hoofdgerecht
                if let options = item["selectedOptions"] as? [[String: Any]], !options.isEmpty {
                    commands.append("\n".data(using: .ascii) ?? Data())  // Afstand van hoofdgerecht
                    for opt in options {
                        if let optName = opt["optionName"] as? String {
                            commands.append("   + \(optName)\n".data(using: .utf8) ?? Data())
                        }
                    }
                }
                
                // LEGE REGEL NA ELK ITEM
                commands.append("\n".data(using: .ascii) ?? Data())
            }
        }
        
        commands.append(sep.data(using: .ascii) ?? Data())
        
        // ==================== TOTALEN ====================
        let subtotal = order["subtotal"] as? Double ?? 0
        let tax = order["tax"] as? Double ?? 0
        let total = order["total"] as? Double ?? 0
        
        // Subtotaal - GROOT
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        let subtotalText = "Subtotaal"
        let subtotalPriceStr = String(format: "E%.2f", subtotal)
        let subtotalPad = max(1, W - subtotalText.count - subtotalPriceStr.count)
        commands.append("\(subtotalText)\(String(repeating: " ", count: subtotalPad))".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.euroSymbol)
        commands.append(String(format: " %.2f\n", subtotal).data(using: .utf8) ?? Data())
        
        // BTW - GROOT
        let taxText = "BTW (9%)"
        let taxPriceStr = String(format: "E %.2f", tax)
        let taxPad = max(1, W - taxText.count - taxPriceStr.count)
        commands.append("\(taxText)\(String(repeating: " ", count: taxPad))".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.euroSymbol)
        commands.append(String(format: " %.2f\n", tax).data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(sep.data(using: .ascii) ?? Data())
        
        // ==================== TOTAAL ====================
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.boldOn)
        commands.append(ESCPOSCommands.doubleHeight)
        let totalText = "TOTAAL"
        let totalPriceStr = String(format: "E%.2f", total)
        let totalPad = max(1, W - totalText.count - totalPriceStr.count)
        commands.append("\(totalText)\(String(repeating: " ", count: totalPad))".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.euroSymbol)
        commands.append(String(format: " %.2f\n", total).data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.normalSize)
        commands.append(ESCPOSCommands.boldOff)
        
        // Betaalmethode
        commands.append("\n".data(using: .ascii) ?? Data())
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
        commands.append("Betaald met: \(paymentLabel)\n".data(using: .utf8) ?? Data())
        
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(sep.data(using: .ascii) ?? Data())
        
        // ==================== FOOTER ====================
        if let vatNumber = businessInfo["vatNumber"] as? String {
            commands.append("\n".data(using: .ascii) ?? Data())
            commands.append("BTW: \(vatNumber)\n".data(using: .utf8) ?? Data())
        }
        
        commands.append("\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.boldOn)
        commands.append("Bedankt voor uw bezoek!\n".data(using: .utf8) ?? Data())
        commands.append(ESCPOSCommands.boldOff)
        
        if let website = businessInfo["website"] as? String {
            commands.append("\(website)\n".data(using: .utf8) ?? Data())
        }
        
        // Ruimte + cut
        commands.append("\n\n\n\n".data(using: .ascii) ?? Data())
        commands.append(ESCPOSCommands.emphasizeOff)
        commands.append(ESCPOSCommands.cutPaper)
        
        // Stuur eerste bon
        let success1 = await sendData(commands, to: ip, port: port)
        if !success1 { return false }
        
        // Korte pauze tussen bonnen
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 sec
        
        // Stuur tweede bon (identiek)
        let success2 = await sendData(commands, to: ip, port: port)
        return success2
    }
}
