import Foundation

actor OpenRouterService {
    static let shared = OpenRouterService()

    func sendMessage(
        messages: [OpenRouterMessage],
        apiKey: String,
        model: String = "openrouter/auto",
        baseURL: String
    ) async throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmed.hasSuffix("/chat/completions") ? trimmed : trimmed + "/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("OpenRouterChat/2.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("OpenRouterChat", forHTTPHeaderField: "X-Title")

        let body = OpenRouterRequest(
            model: model,
            messages: messages
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        return decoded.choices?.first?.message?.content ?? ""
    }

    func sendStreamingMessage(messages: [OpenRouterMessage], apiKey: String, model: String = "openrouter/auto", baseURL: String) async throws -> AsyncThrowingStream<String, Error> {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmed.hasSuffix("/chat/completions") ? trimmed : trimmed + "/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("OpenRouterChat/2.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("OpenRouterChat", forHTTPHeaderField: "X-Title")

        let body = OpenRouterRequest(
            model: model,
            messages: messages,
            stream: true
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines where line.hasPrefix("data: ") {
                        let dataStr = String(line.dropFirst(6))
                        if dataStr == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        if let data = dataStr.data(using: .utf8),
                           let streamResponse = try? JSONDecoder().decode(StreamResponse.self, from: data),
                           let content = streamResponse.choices?.first?.delta?.content {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func fetchModels(baseURL: String, apiKey: String) async throws -> [String] {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelsURLString = trimmed.hasSuffix("/models") ? trimmed : trimmed + "/models"
        guard let url = URL(string: modelsURLString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map { $0.id }
    }

    func transcribeAudio(audioData: Data, apiKey: String, baseURL: String) async throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.replacingOccurrences(of: "/chat/completions", with: "")
            .replacingOccurrences(of: "/models", with: "")
        let urlString = base + "/audio/transcriptions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }

        return ""
    }

    // MARK: - MCP Server Communication

    func callMCPTool(name: String, parameters: [String: Any], serverURL: String) async throws -> String {
        guard let url = URL(string: serverURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "tool": name,
            "parameters": parameters
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? String {
            return result
        }

        return ""
    }

    // MARK: - Image Generation

    func generateImage(prompt: String, apiKey: String, baseURL: String) async throws -> Data {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.replacingOccurrences(of: "/chat/completions", with: "")
            .replacingOccurrences(of: "/models", with: "")
        let urlString = base + "/images/generations"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let images = json["data"] as? [[String: String]],
           let b64 = images.first?["b64_json"] {
            return Data(base64Encoded: b64) ?? Data()
        }

        return data
    }
}
