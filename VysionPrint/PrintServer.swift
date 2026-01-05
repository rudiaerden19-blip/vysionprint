import Foundation
import Network

class PrintServer: ObservableObject {
    @Published var isRunning = false
    @Published var printCount = 0
    @Published var lastPrintTime: Date?
    
    var printerManager: PrinterManager?
    
    private var listener: NWListener?
    private let port: UInt16 = 3001
    
    func start() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("Print server started on port \(self?.port ?? 0)")
                    case .failed(let error):
                        self?.isRunning = false
                        print("Print server failed: \(error)")
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
            
        } catch {
            print("Failed to start print server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveData(connection)
            case .failed(_), .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global())
    }
    
    private func receiveData(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processRequest(data: data, connection: connection)
            }
            
            if isComplete || error != nil {
                connection.cancel()
            } else {
                self?.receiveData(connection)
            }
        }
    }
    
    private func processRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid request\"}")
            return
        }
        
        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid request\"}")
            return
        }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid request\"}")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        // CORS preflight
        if method == "OPTIONS" {
            sendCORSResponse(connection: connection)
            return
        }
        
        // Find body (after empty line)
        var body = ""
        if let emptyLineIndex = lines.firstIndex(of: "") {
            let bodyLines = lines[(emptyLineIndex + 1)...]
            body = bodyLines.joined(separator: "\r\n")
        }
        
        // Route handling
        switch (method, path) {
        case ("GET", "/status"):
            let response = "{\"status\":\"online\",\"printer\":\"\(printerManager?.printerIP ?? "not configured")\"}"
            sendResponse(connection: connection, statusCode: 200, body: response)
            
        case ("POST", "/print"):
            handlePrint(body: body, connection: connection)
            
        case ("POST", "/drawer"):
            handleDrawer(connection: connection)
            
        case ("POST", "/test"):
            handleTest(connection: connection)
            
        case ("GET", "/"):
            let html = """
            <html>
            <head><title>Vysion Print Server</title></head>
            <body style="font-family: sans-serif; padding: 40px; background: #1a1a2e; color: #fff;">
            <h1>🖨️ Vysion Print Server</h1>
            <p style="color: #22c55e;">✅ iOS App actief</p>
            <p>Printer: \(printerManager?.printerIP ?? "niet geconfigureerd")</p>
            <p>Bonnen geprint: \(printCount)</p>
            </body>
            </html>
            """
            sendResponse(connection: connection, statusCode: 200, body: html, contentType: "text/html")
            
        default:
            sendResponse(connection: connection, statusCode: 404, body: "{\"error\":\"Not found\"}")
        }
    }
    
    private func handlePrint(body: String, connection: NWConnection) {
        guard let jsonData = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let order = json["order"] as? [String: Any] else {
            sendResponse(connection: connection, statusCode: 400, body: "{\"error\":\"Invalid order data\"}")
            return
        }
        
        let businessInfo = json["businessInfo"] as? [String: Any] ?? [:]
        
        Task {
            let success = await printerManager?.printReceipt(order: order, businessInfo: businessInfo) ?? false
            
            await MainActor.run {
                if success {
                    self.printCount += 1
                    self.lastPrintTime = Date()
                }
            }
            
            if success {
                sendResponse(connection: connection, statusCode: 200, body: "{\"success\":true}")
            } else {
                sendResponse(connection: connection, statusCode: 500, body: "{\"error\":\"Print failed\"}")
            }
        }
    }
    
    private func handleDrawer(connection: NWConnection) {
        Task {
            let success = await printerManager?.openCashDrawer() ?? false
            if success {
                sendResponse(connection: connection, statusCode: 200, body: "{\"success\":true}")
            } else {
                sendResponse(connection: connection, statusCode: 500, body: "{\"error\":\"Drawer failed\"}")
            }
        }
    }
    
    private func handleTest(connection: NWConnection) {
        Task {
            let success = await printerManager?.sendTestPrint() ?? false
            
            await MainActor.run {
                if success {
                    self.printCount += 1
                    self.lastPrintTime = Date()
                }
            }
            
            if success {
                sendResponse(connection: connection, statusCode: 200, body: "{\"success\":true}")
            } else {
                sendResponse(connection: connection, statusCode: 500, body: "{\"error\":\"Test print failed\"}")
            }
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "application/json") {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }
        
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Connection: close\r
        \r
        \(body)
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendCORSResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Content-Length: 0\r
        Connection: close\r
        \r
        
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
