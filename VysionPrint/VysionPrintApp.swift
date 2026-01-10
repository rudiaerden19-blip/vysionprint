import SwiftUI

@main
struct VysionPrintApp: App {
    @StateObject private var printerManager = PrinterManager()
    @StateObject private var printServer = PrintServer()
    
    var body: some Scene {
        WindowGroup {
            MainKassaView()
                .environmentObject(printerManager)
                .environmentObject(printServer)
                .onAppear {
                    // Start print server wanneer app opent
                    printServer.printerManager = printerManager
                    printServer.start()
                }
        }
    }
}
