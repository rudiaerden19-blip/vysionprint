import SwiftUI
import WebKit

/// WebView die de Vysion Kassa laadt
struct KassaWebView: UIViewRepresentable {
    let url: URL
    let printServer: PrintServer
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Message handler voor print requests
        configuration.userContentController.add(context.coordinator, name: "vysionPrint")
        
        // JavaScript injecteren dat fetch override voor print server
        let script = WKUserScript(
            source: """
            // Vysion Print Bridge
            (function() {
                // Markeer dat we in de Vysion Print app draaien
                window._vysionPrintApp = true;
                
                const originalFetch = window.fetch;
                window.fetch = async function(url, options) {
                    const urlStr = typeof url === 'string' ? url : url.toString();
                    if (urlStr.includes(':3001') || urlStr.includes('localhost')) {
                        // Extract path
                        const pathMatch = urlStr.match(/\\/(status|print|test|drawer|config)/);
                        const path = pathMatch ? '/' + pathMatch[1] : '/status';
                        
                        // Send via message handler
                        return new Promise((resolve, reject) => {
                            const requestId = Date.now().toString();
                            
                            // Store resolver
                            window._vysionResolvers = window._vysionResolvers || {};
                            window._vysionResolvers[requestId] = { resolve, reject };
                            
                            // Send to native
                            window.webkit.messageHandlers.vysionPrint.postMessage({
                                requestId: requestId,
                                path: path,
                                method: options?.method || 'GET',
                                body: options?.body || null
                            });
                        });
                    }
                    return originalFetch.apply(this, arguments);
                };
                
                // Handler for responses from native
                window._vysionResponse = function(requestId, success, data) {
                    const resolver = window._vysionResolvers[requestId];
                    if (resolver) {
                        if (success) {
                            resolver.resolve(new Response(JSON.stringify(data), {
                                status: 200,
                                headers: { 'Content-Type': 'application/json' }
                            }));
                        } else {
                            resolver.reject(new Error(data.error || 'Request failed'));
                        }
                        delete window._vysionResolvers[requestId];
                    }
                };
                
                console.log('Vysion Print Bridge geïnstalleerd');
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(script)
        
        // Pop-ups toestaan voor printen
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Laden
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        var parent: KassaWebView
        weak var webView: WKWebView?
        
        init(_ parent: KassaWebView) {
            self.parent = parent
        }
        
        // Handle pop-ups (voor printen) - negeer ze, print gaat via native bridge
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Negeer pop-ups - de print gaat via de native Vysion Print bridge
            // Dit voorkomt dat window.open() de app crasht
            return nil
        }
        
        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let requestId = body["requestId"] as? String,
                  let path = body["path"] as? String else {
                return
            }
            
            let _ = body["method"] as? String ?? "GET"  // Voor toekomstig gebruik
            let bodyData = body["body"] as? String
            
            Task {
                var success = false
                var responseData: [String: Any] = [:]
                
                switch path {
                case "/status":
                    responseData = [
                        "status": "online",
                        "printer": parent.printServer.printerManager?.printerIP ?? "not configured"
                    ]
                    success = true
                    
                case "/print":
                    if let bodyData = bodyData,
                       let jsonData = bodyData.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let order = json["order"] as? [String: Any] {
                        let businessInfo = json["businessInfo"] as? [String: Any] ?? [:]
                        success = await parent.printServer.printerManager?.printReceipt(order: order, businessInfo: businessInfo) ?? false
                        if success {
                            await MainActor.run {
                                parent.printServer.printCount += 1
                                parent.printServer.lastPrintTime = Date()
                            }
                        }
                        responseData = success ? ["success": true] : ["error": "Print failed"]
                    } else {
                        responseData = ["error": "Invalid request"]
                    }
                    
                case "/drawer":
                    success = await parent.printServer.printerManager?.openCashDrawer() ?? false
                    responseData = success ? ["success": true] : ["error": "Drawer failed"]
                    
                case "/test":
                    success = await parent.printServer.printerManager?.sendTestPrint() ?? false
                    if success {
                        await MainActor.run {
                            parent.printServer.printCount += 1
                            parent.printServer.lastPrintTime = Date()
                        }
                    }
                    responseData = success ? ["success": true] : ["error": "Test failed"]
                    
                default:
                    responseData = ["error": "Unknown path"]
                }
                
                // Send response back to JavaScript
                await MainActor.run {
                    let jsonString = (try? JSONSerialization.data(withJSONObject: responseData))
                        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    let js = "window._vysionResponse('\(requestId)', \(success), \(jsonString));"
                    message.webView?.evaluateJavaScript(js)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
        }
    }
}

/// Full screen kassa view
struct KassaView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var printServer: PrintServer
    
    let kassaURL = URL(string: "https://frituurnolim.vercel.app/kassa")!
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Kassa WebView - volledig scherm
            KassaWebView(url: kassaURL, printServer: printServer)
                .ignoresSafeArea()
            
            // Sluit knop linksboven naast hamburger menu
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .padding(.top, 8)
            .padding(.leading, 240)
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
