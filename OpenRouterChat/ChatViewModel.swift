import Foundation
import SwiftData
import AVFoundation
import Accelerate
import NaturalLanguage

@Observable
class ChatViewModel {
    var isLoading = false
    var isStreaming = false
    var errorMessage: String?
    var availableModels: [String] = []
    var isLoadingModels = false
    var modelsLoadError: String?
    var streamBuffer = ""
    var currentStreamingMessage: Message?
    var tokenUsage: UsageInfo?

    // Voice
    var isRecording = false
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?
    var recordingDuration: TimeInterval = 0
    var recordingTimer: Timer?

    // Agents
    var activeAgents: [AgentTask] = []
    var agentResults: [AgentResult] = []

    // MCP
    var mcpTools: [MCPFunction] = []
    var isMCPLoading = false

    // Memory
    var memoryStatus: String = ""

    @MainActor
    func loadModels(baseURL: String, apiKey: String) async {
        isLoadingModels = true
        modelsLoadError = nil
        defer { isLoadingModels = false }

        do {
            let models = try await OpenRouterService.shared.fetchModels(baseURL: baseURL, apiKey: apiKey)
            availableModels = models
        } catch {
            modelsLoadError = error.localizedDescription
            availableModels = fallbackModels2026.map { $0.name }
        }
    }

    // MARK: - Streaming Message

    @MainActor
    func sendStreamingMessage(_ content: String, chat: Chat, modelContext: ModelContext, apiKey: String, baseURL: String, imageBase64: String? = nil) async {
        guard !apiKey.isEmpty else {
            errorMessage = "API key is not set. Please configure it in Settings."
            return
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let userMessage = Message(role: "user", content: content, chat: chat, imageBase64: imageBase64)
        modelContext.insert(userMessage)
        try? modelContext.save()

        isLoading = true
        isStreaming = true
        errorMessage = nil
        streamBuffer = ""

        var messages = buildMessages(for: chat, includeImage: imageBase64, userContent: content)

        let requestBody = OpenRouterRequest(
            model: chat.model,
            messages: messages,
            stream: true
        )

        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmed.hasSuffix("/chat/completions") ? trimmed : trimmed + "/chat/completions"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid API URL"
            isLoading = false
            isStreaming = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("OpenRouterChat/2.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("OpenRouterChat", forHTTPHeaderField: "X-Title")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            isLoading = false
            isStreaming = false
            return
        }

        let assistantMessage = Message(role: "assistant", content: "", chat: chat, isStreaming: true)
        modelContext.insert(assistantMessage)
        currentStreamingMessage = assistantMessage
        try? modelContext.save()

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                isLoading = false
                isStreaming = false
                assistantMessage.isStreaming = false
                try? modelContext.save()
                return
            }

            var fullContent = ""
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let dataStr = String(line.dropFirst(6))
                    if dataStr == "[DONE]" { break }

                    if let data = dataStr.data(using: .utf8),
                       let streamResponse = try? JSONDecoder().decode(StreamResponse.self, from: data) {
                        if let delta = streamResponse.choices?.first?.delta?.content {
                            fullContent += delta
                            streamBuffer = fullContent
                            assistantMessage.content = fullContent
                            try? modelContext.save()
                        }
                        if let usage = streamResponse.usage {
                            tokenUsage = usage
                        }
                    }
                }
            }

            assistantMessage.content = fullContent
            assistantMessage.isStreaming = false
            try? modelContext.save()

            // Save to memory
            await saveToMemory(content: fullContent, chat: chat, modelContext: modelContext)

        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            assistantMessage.isError = true
            assistantMessage.isStreaming = false
            try? modelContext.save()
        }

        isLoading = false
        isStreaming = false
        currentStreamingMessage = nil
    }

    // MARK: - Non-streaming (fallback)

    @MainActor
    func sendMessage(_ content: String, chat: Chat, modelContext: ModelContext, apiKey: String, baseURL: String, imageBase64: String? = nil) async {
        guard !apiKey.isEmpty else {
            errorMessage = "API key is not set. Please configure it in Settings."
            return
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let userMessage = Message(role: "user", content: content, chat: chat, imageBase64: imageBase64)
        modelContext.insert(userMessage)
        try? modelContext.save()

        isLoading = true
        errorMessage = nil

        var messages = buildMessages(for: chat, includeImage: imageBase64, userContent: content)

        let requestBody = OpenRouterRequest(
            model: chat.model,
            messages: messages
        )

        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmed.hasSuffix("/chat/completions") ? trimmed : trimmed + "/chat/completions"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid API URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("OpenRouterChat/2.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("OpenRouterChat", forHTTPHeaderField: "X-Title")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let errorJson = try? JSONDecoder().decode(OpenRouterResponse.self, from: data),
                   let errorMsg = errorJson.error?.message {
                    errorMessage = "API Error: \(errorMsg)"
                } else {
                    errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                }
                isLoading = false
                return
            }

            let decodedResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)

            if let error = decodedResponse.error, let msg = error.message {
                errorMessage = "API Error: \(msg)"
                isLoading = false
                return
            }

            guard let assistantContent = decodedResponse.choices?.first?.message?.content else {
                errorMessage = "No response from model"
                isLoading = false
                return
            }

            let assistantMessage = Message(role: "assistant", content: assistantContent, chat: chat)
            modelContext.insert(assistantMessage)
            try modelContext.save()

            tokenUsage = decodedResponse.usage
            await saveToMemory(content: assistantContent, chat: chat, modelContext: modelContext)

        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func buildMessages(for chat: Chat, includeImage: String?, userContent: String) -> [OpenRouterMessage] {
        var messages: [OpenRouterMessage] = []

        if let systemPrompt = chat.systemPrompt, !systemPrompt.isEmpty {
            messages.append(OpenRouterMessage(role: "system", content: systemPrompt))
        }

        // Add relevant memories
        if let memories = chat.memories, !memories.isEmpty {
            let memoryContext = memories.prefix(3).map { $0.content }.joined(separator: "\n")
            messages.append(OpenRouterMessage(role: "system", content: "Relevant context from previous conversations:\n\(memoryContext)"))
        }

        if let chatMessages = chat.messages?.sorted(by: { $0.timestamp < $1.timestamp }) {
            for msg in chatMessages {
                if let imgB64 = msg.imageBase64, !imgB64.isEmpty {
                    var parts: [ContentPart] = []
                    if !msg.content.isEmpty {
                        parts.append(ContentPart(type: "text", text: msg.content, image_url: nil))
                    }
                    parts.append(ContentPart(type: "image_url", text: nil, image_url: ImageURLData(url: "data:image/jpeg;base64,\(imgB64)")))
                    messages.append(OpenRouterMessage(role: msg.role, content: parts))
                } else {
                    messages.append(OpenRouterMessage(role: msg.role, content: msg.content))
                }
            }
        }

        // Add current message with image if present
        if let imgB64 = includeImage, !imgB64.isEmpty {
            var parts: [ContentPart] = []
            if !userContent.isEmpty {
                parts.append(ContentPart(type: "text", text: userContent, image_url: nil))
            }
            parts.append(ContentPart(type: "image_url", text: nil, image_url: ImageURLData(url: "data:image/jpeg;base64,\(imgB64)")))
            messages.append(OpenRouterMessage(role: "user", content: parts))
        }

        return messages
    }

    // MARK: - Memory / RAG

    @MainActor
    private func saveToMemory(content: String, chat: Chat, modelContext: ModelContext) async {
        let summary = String(content.prefix(500))
        let memory = ChatMemory(content: summary, memoryType: "short", chat: chat)
        modelContext.insert(memory)
        try? modelContext.save()
    }

    // MARK: - Title Generation

    @MainActor
    func generateChatTitle(for chat: Chat, modelContext: ModelContext, apiKey: String, baseURL: String) async {
        guard !apiKey.isEmpty, let firstMessage = chat.messages?.first(where: { $0.role == "user" }) else { return }

        let prompt = "Generate a short 2-4 word title for this chat based on the first message: \"\(firstMessage.content.prefix(200))\". Respond with ONLY the title, no quotes."

        let requestBody = OpenRouterRequest(
            model: "openai/gpt-4o-mini",
            messages: [OpenRouterMessage(role: "user", content: prompt)],
            maxTokens: 20
        )

        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = trimmed.hasSuffix("/chat/completions") ? trimmed : trimmed + "/chat/completions"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("OpenRouterChat/2.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("OpenRouterChat", forHTTPHeaderField: "X-Title")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
            if let title = decoded.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) {
                chat.title = title
                try modelContext.save()
            }
        } catch {
            // Silently fail title generation
        }
    }

    // MARK: - Voice Recording

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording_\(UUID().uuidString).wav")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    @MainActor
    func transcribeRecording(apiKey: String, baseURL: String) async -> String {
        guard let url = recordingURL else { return "" }
        defer {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        do {
            let data = try Data(contentsOf: url)
            let text = try await OpenRouterService.shared.transcribeAudio(audioData: data, apiKey: apiKey, baseURL: baseURL)
            return text
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            return ""
        }
    }

    // MARK: - Local Whisper (on-device)

    @MainActor
    func transcribeWithLocalWhisper() async -> String {
        guard let url = recordingURL else { return "" }
        defer {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        do {
            let data = try Data(contentsOf: url)
            let whisper = try await LocalWhisperEngine.shared
            let text = try await whisper.transcribe(audioData: data)
            return text
        } catch {
            errorMessage = "Local transcription failed: \(error.localizedDescription)"
            return ""
        }
    }

    // MARK: - Agent Swarm

    @MainActor
    func runAgentSwarm(task: String, chat: Chat, modelContext: ModelContext, apiKey: String, baseURL: String) async {
        let agents = [
            AgentTask(name: "Researcher", prompt: "Research and gather information about: \(task)"),
            AgentTask(name: "Analyst", prompt: "Analyze the following topic and provide insights: \(task)"),
            AgentTask(name: "Writer", prompt: "Write a comprehensive response about: \(task)")
        ]

        activeAgents = agents
        agentResults = []

        await withTaskGroup(of: AgentResult.self) { group in
            for agent in agents {
                group.addTask {
                    do {
                        let result = try await OpenRouterService.shared.sendMessage(
                            messages: [OpenRouterMessage(role: "user", content: agent.prompt)],
                            apiKey: apiKey,
                            model: chat.model,
                            baseURL: baseURL
                        )
                        return AgentResult(agentName: agent.name, content: result, isSuccess: true)
                    } catch {
                        return AgentResult(agentName: agent.name, content: error.localizedDescription, isSuccess: false)
                    }
                }
            }

            for await result in group {
                agentResults.append(result)
            }
        }

        // Synthesize results
        let synthesis = agentResults.map { "[\($0.agentName)]: \($0.content)" }.joined(separator: "\n\n")
        let finalPrompt = "Synthesize the following agent outputs into a cohesive response:\n\n\(synthesis)"

        do {
            let finalResult = try await OpenRouterService.shared.sendMessage(
                messages: [OpenRouterMessage(role: "user", content: finalPrompt)],
                apiKey: apiKey,
                model: chat.model,
                baseURL: baseURL
            )

            let message = Message(role: "assistant", content: finalResult, chat: chat)
            modelContext.insert(message)
            try modelContext.save()
        } catch {
            errorMessage = "Agent synthesis failed: \(error.localizedDescription)"
        }

        activeAgents = []
    }

    // MARK: - MCP Tools

    @MainActor
    func loadMCPTools(from serverURL: String) async {
        isMCPLoading = true
        defer { isMCPLoading = false }

        // MCP tool loading would connect to external MCP servers
        // For now, define common tools
        mcpTools = [
            MCPFunction(name: "web_search", description: "Search the web for current information"),
            MCPFunction(name: "code_interpreter", description: "Execute and analyze code"),
            MCPFunction(name: "file_manager", description: "Manage files and documents")
        ]
    }
}

// MARK: - Supporting Types

struct StreamResponse: Codable {
    let choices: [StreamChoice]?
    let usage: UsageInfo?
}

struct StreamChoice: Codable {
    let delta: DeltaMessage?
    let finish_reason: String?
}

struct AgentTask: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
}

struct AgentResult: Identifiable {
    let id = UUID()
    let agentName: String
    let content: String
    let isSuccess: Bool
}

struct MCPFunction: Identifiable {
    let id = UUID()
    let name: String
    let description: String
}

// MARK: - Local Whisper Engine

actor LocalWhisperEngine {
    static let shared = LocalWhisperEngine()
    private var isInitialized = false

    private init() {}

    func transcribe(audioData: Data) async throws -> String {
        // Placeholder for on-device Whisper implementation
        // In production, this would use Core ML or a custom Whisper implementation
        // For iOS 26, we can use the built-in Speech framework with on-device recognition
        // or integrate whisper.cpp compiled for iOS

        // For now, return a placeholder that indicates local processing
        return "[Local Whisper: Audio processed on-device]"
    }
}
