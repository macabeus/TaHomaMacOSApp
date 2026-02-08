import Foundation
import OSLog
import Security

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "TaHomaClient")

// MARK: - TLS Delegate

/// URLSession delegate that validates the server certificate against the bundled Overkiz root CA.
final class OverkizTLSDelegate: NSObject, URLSessionDelegate {
    private let rootCA: SecCertificate?

    override init() {
        if let caURL = Bundle.main.url(forResource: "OverkizRootCA", withExtension: "der"),
           let caData = try? Data(contentsOf: caURL),
           let cert = SecCertificateCreateWithData(nil, caData as CFData) {
            rootCA = cert
        } else {
            // Try widget bundle
            let bundles = Bundle.allBundles + [Bundle.main]
            var found: SecCertificate?
            for bundle in bundles {
                if let caURL = bundle.url(forResource: "OverkizRootCA", withExtension: "der"),
                   let caData = try? Data(contentsOf: caURL),
                   let cert = SecCertificateCreateWithData(nil, caData as CFData) {
                    found = cert
                    break
                }
            }
            rootCA = found
        }
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let rootCA = rootCA else {
            logger.error("OverkizRootCA.der not found in any bundle — cancelling TLS challenge")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        SecTrustSetAnchorCertificates(serverTrust, [rootCA] as CFArray)
        SecTrustSetAnchorCertificatesOnly(serverTrust, true)

        // The Overkiz device certificate has a 10-year validity period which
        // fails Apple's strict "standards compliant" check. Use a basic X.509
        // policy instead of the default SSL policy so that the chain-of-trust
        // is verified without rejecting non-compliant leaf certificates.
        let basicPolicy = SecPolicyCreateBasicX509()
        SecTrustSetPolicies(serverTrust, basicPolicy)

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            logger.debug("TLS trust evaluation succeeded for \(challenge.protectionSpace.host)")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            logger.error("TLS trust evaluation failed: \(error?.localizedDescription ?? "unknown error")")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - API Errors

enum TaHomaError: LocalizedError {
    case notConfigured
    case networkError(Error)
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Gateway PIN, token, or device URL not configured."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Client

final class TaHomaClient {
    let gatewayPin: String
    let token: String
    private let session: URLSession

    var baseURL: URL {
        return URL(string: "https://gateway-\(gatewayPin).local:8443/enduser-mobile-web/1/enduserAPI")!
    }

    init(gatewayPin: String, token: String) {
        self.gatewayPin = gatewayPin
        self.token = token
        let delegate = OverkizTLSDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    /// Creates a client from saved credentials, or returns nil if not configured.
    static func fromKeychain() -> TaHomaClient? {
        guard let pin = KeychainHelper.loadGatewayPin(),
              let token = KeychainHelper.loadToken() else {
            return nil
        }
        return TaHomaClient(gatewayPin: pin, token: token)
    }

    // MARK: - API Methods

    func listDevices() async throws -> [TaHomaDevice] {
        let url = baseURL.appendingPathComponent("setup/devices")
        return try await request(url: url)
    }

    func getDeviceState(deviceURL: String) async throws -> [DeviceState] {
        let encoded = encodeDeviceURL(deviceURL)
        let url = URL(string: "\(baseURL)/setup/devices/\(encoded)/states")!
        return try await request(url: url)
    }

    @discardableResult
    func sendCommand(deviceURL: String, command: String, parameters: [Int] = []) async throws -> String {
        let url = baseURL.appendingPathComponent("exec/apply")

        let body = CommandRequest(
            label: "Widget: \(command)",
            actions: [
                Action(
                    deviceURL: deviceURL,
                    commands: [
                        Command(name: command, parameters: parameters)
                    ]
                )
            ]
        )

        let response: ExecutionResponse = try await request(url: url, method: "POST", body: body)
        return response.execId
    }

    // MARK: - Private

    private func encodeDeviceURL(_ deviceURL: String) -> String {
        deviceURL
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: "-._~"))) ?? deviceURL
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(req)
        return try decodeResponse(data: data, response: response)
    }

    private func request<T: Decodable, B: Encodable>(url: URL, method: String, body: B) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(req)
        return try decodeResponse(data: data, response: response)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        logger.debug("Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                logger.debug("Response: HTTP \(http.statusCode), \(data.count) bytes")
            }
            return (data, response)
        } catch {
            logger.error("Network request failed: \(error)")
            throw TaHomaError.networkError(error)
        }
    }

    private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TaHomaError.httpError(httpResponse.statusCode, body)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let decodingError {
            logger.error("JSON decoding failed for \(T.self): \(decodingError)")
            if let bodyPreview = String(data: data.prefix(500), encoding: .utf8) {
                logger.error("Response body preview: \(bodyPreview)")
            }
            throw TaHomaError.decodingError(decodingError)
        }
    }
}
