import Foundation
import Security

final class KeychainStore {
    static let shared = KeychainStore()
    private let service = "com.example.TextRefiner"
    private let account = "openai-api-key"

    func read() -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                       kSecAttrAccount: account, kSecReturnData: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ key: String) throws {
        let attributes: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                            kSecAttrAccount: account]
        let data = Data(key.utf8)
        let status = SecItemUpdate(attributes as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = attributes
            newItem[kSecValueData] = data
            guard SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess else { throw KeychainError.saveFailed }
        } else if status != errSecSuccess { throw KeychainError.saveFailed }
    }
    enum KeychainError: LocalizedError { case saveFailed; var errorDescription: String? { "Keychain returned an error." } }
}

struct Refinements: Decodable { let shorter: String; let clearer: String; let formal: String }

enum OpenAIService {
    // Change this in one place if your project uses a different available text model.
    static let model = "gpt-5-mini"

    static func refine(_ selection: String) async throws -> Refinements {
        guard let key = KeychainStore.shared.read(), !key.isEmpty else { throw ServiceError.missingKey }
        let instructions = "Return only a JSON object with exactly these string keys: shorter, clearer, formal. Preserve the input language and meaning. Do not include markdown."
        let body: [String: Any] = ["model": model, "instructions": instructions, "input": selection]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "Unknown API error")
        }
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let text = envelope.output.flatMap(\.content).first(where: { $0.type == "output_text" })?.text,
              let json = text.data(using: .utf8) else { throw ServiceError.invalidResponse }
        return try JSONDecoder().decode(Refinements.self, from: json)
    }

    private struct ResponseEnvelope: Decodable { let output: [Output]; struct Output: Decodable { let content: [Content] }; struct Content: Decodable { let type: String; let text: String? } }
    enum ServiceError: LocalizedError {
        case missingKey, invalidResponse, requestFailed(String)
        var errorDescription: String? { switch self { case .missingKey: return "Set an OpenAI API key from the menu-bar icon first."; case .invalidResponse: return "The API returned an unexpected response."; case .requestFailed(let message): return message } }
    }
}
