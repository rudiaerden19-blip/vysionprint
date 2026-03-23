import Foundation
import Security
import UIKit

/// InstallManager handles the zero-setup install flow
/// - Reads install token from URL or clipboard
/// - Validates token with backend
/// - Stores device config in Keychain
/// - Backward compatible: Frituur Nolim blijft werken
class InstallManager: ObservableObject {
    static let shared = InstallManager()
    
    // Published state
    @Published var isInstalling = false
    @Published var isInstalled = false
    @Published var installError: String?
    @Published var tenantConfig: TenantConfig?
    
    // Keychain keys
    private let deviceIdKey = "vysion_device_id"
    private let tenantConfigKey = "vysion_tenant_config"
    private let legacyFrituurNolimKey = "vysion_legacy_frituur_nolim"
    
    // API base URL
    private let apiBaseURL = "https://appvysion.com"
    
    // MARK: - Initialization
    
    init() {
        loadStoredConfig()
    }
    
    // MARK: - Check Install Status
    
    /// Check if device is already installed/activated
    func checkInstallStatus() -> InstallStatus {
        // 1. Check if we have a device_id (new install system)
        if let deviceId = getKeychainString(key: deviceIdKey),
           let config = loadTenantConfig() {
            self.tenantConfig = config
            self.isInstalled = true
            return .installed(config: config)
        }
        
        // 2. Check for legacy Frituur Nolim installation
        if getKeychainString(key: legacyFrituurNolimKey) != nil {
            let legacyConfig = TenantConfig(
                id: "d4591439-5fe7-4ed6-98bd-4ae032e41f52",
                name: "Frituur Nolim",
                kassaURL: "https://frituurnolim.vercel.app/kassa",
                printerVendor: "AUTO",
                locale: "nl-BE",
                btw: 6
            )
            self.tenantConfig = legacyConfig
            self.isInstalled = true
            return .legacyInstalled(config: legacyConfig)
        }
        
        // 3. Not installed
        return .notInstalled
    }
    
    // MARK: - Install Flow
    
    /// Run the install flow with a token
    func runInstallFlow(token: String) async -> Bool {
        await MainActor.run {
            self.isInstalling = true
            self.installError = nil
        }
        
        do {
            // 1. Get device info
            let device = DeviceInfo.current()
            
            // 2. Validate token with backend
            let response = try await validateToken(token: token, device: device)
            
            // 3. Store device_id in Keychain
            setKeychainString(key: deviceIdKey, value: response.deviceId)
            
            // 4. Store tenant config
            saveTenantConfig(response.tenant)
            
            // 5. Update state
            await MainActor.run {
                self.tenantConfig = response.tenant
                self.isInstalled = true
                self.isInstalling = false
            }
            
            return true
            
        } catch let error as InstallError {
            await MainActor.run {
                self.installError = error.userMessage
                self.isInstalling = false
            }
            return false
            
        } catch {
            await MainActor.run {
                self.installError = "Installatie mislukt. Probeer opnieuw."
                self.isInstalling = false
            }
            return false
        }
    }
    
    /// Mark as legacy Frituur Nolim installation (for existing devices)
    func markAsLegacyFrituurNolim() {
        setKeychainString(key: legacyFrituurNolimKey, value: "true")
        let config = TenantConfig(
            id: "d4591439-5fe7-4ed6-98bd-4ae032e41f52",
            name: "Frituur Nolim",
            kassaURL: "https://frituurnolim.vercel.app/kassa",
            printerVendor: "AUTO",
            locale: "nl-BE",
            btw: 6
        )
        self.tenantConfig = config
        self.isInstalled = true
    }
    
    // MARK: - API Calls
    
    private func validateToken(token: String, device: DeviceInfo) async throws -> ValidateResponse {
        guard let url = URL(string: "\(apiBaseURL)/api/install/validate") else {
            throw InstallError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "token": token,
            "device": [
                "uuid": device.uuid,
                "model": device.model,
                "ios": device.iosVersion,
                "app": device.appVersion,
                "name": device.name
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstallError.networkError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        switch httpResponse.statusCode {
        case 200:
            guard let deviceId = json?["device_id"] as? String,
                  let tenantDict = json?["tenant"] as? [String: Any] else {
                throw InstallError.invalidResponse
            }
            
            let tenant = TenantConfig(
                id: tenantDict["id"] as? String ?? "",
                name: tenantDict["name"] as? String ?? "",
                kassaURL: tenantDict["kassa_url"] as? String ?? "",
                printerVendor: tenantDict["printer_vendor"] as? String ?? "AUTO",
                locale: tenantDict["locale"] as? String ?? "nl-BE",
                btw: tenantDict["btw"] as? Int ?? 6
            )
            
            return ValidateResponse(deviceId: deviceId, tenant: tenant)
            
        case 401:
            throw InstallError.invalidToken
        case 409:
            throw InstallError.tokenAlreadyUsed
        case 410:
            throw InstallError.tokenExpired
        default:
            throw InstallError.serverError(code: httpResponse.statusCode)
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func setKeychainString(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getKeychainString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    // MARK: - Config Storage
    
    private func saveTenantConfig(_ config: TenantConfig) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(config) {
            UserDefaults.standard.set(data, forKey: tenantConfigKey)
        }
    }
    
    private func loadTenantConfig() -> TenantConfig? {
        guard let data = UserDefaults.standard.data(forKey: tenantConfigKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(TenantConfig.self, from: data)
    }
    
    private func loadStoredConfig() {
        if let config = loadTenantConfig() {
            self.tenantConfig = config
            self.isInstalled = true
        }
    }
}

// MARK: - Data Models

struct TenantConfig: Codable {
    let id: String
    let name: String
    let kassaURL: String
    let printerVendor: String
    let locale: String
    let btw: Int
}

struct DeviceInfo {
    let uuid: String
    let model: String
    let iosVersion: String
    let appVersion: String
    let name: String
    
    static func current() -> DeviceInfo {
        let device = UIDevice.current
        return DeviceInfo(
            uuid: device.identifierForVendor?.uuidString ?? UUID().uuidString,
            model: device.model,
            iosVersion: device.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            name: device.name
        )
    }
}

struct ValidateResponse {
    let deviceId: String
    let tenant: TenantConfig
}

enum InstallStatus {
    case notInstalled
    case installed(config: TenantConfig)
    case legacyInstalled(config: TenantConfig)
}

enum InstallError: Error {
    case invalidURL
    case networkError
    case invalidResponse
    case invalidToken
    case tokenAlreadyUsed
    case tokenExpired
    case serverError(code: Int)
    
    var userMessage: String {
        switch self {
        case .invalidToken:
            return "Ongeldige installatiecode. Vraag een nieuwe aan."
        case .tokenAlreadyUsed:
            return "Deze code is al gebruikt."
        case .tokenExpired:
            return "Deze code is verlopen. Vraag een nieuwe aan."
        case .networkError:
            return "Geen internetverbinding. Controleer je WiFi."
        default:
            return "Installatie mislukt. Probeer opnieuw."
        }
    }
}
