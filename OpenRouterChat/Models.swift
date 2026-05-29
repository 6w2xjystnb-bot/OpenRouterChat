import SwiftData
import Foundation
import SwiftUI

// MARK: - API Providers

enum APIProvider: String, CaseIterable, Identifiable {
    case openrouter = "openrouter"
    case routerai = "routerai"
    case vsegpt = "vsegpt"
    case bothub = "bothub"
    case vsellm = "vsellm"
    case deepseek = "deepseek"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openrouter: return "OpenRouter"
        case .routerai: return "RouterAI"
        case .vsegpt: return "VseGPT"
        case .bothub: return "BotHub"
        case .vsellm: return "VseLLM"
        case .deepseek: return "DeepSeek"
        case .custom: return "Custom"
        }
    }

    var baseURL: String {
        switch self {
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .routerai: return "https://routerai.ru/api/v1"
        case .vsegpt: return "https://api.vsegpt.ru/v1"
        case .bothub: return "https://bothub.chat/api/v2/openai/v1"
        case .vsellm: return "https://api.vsellm.ru/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .custom: return ""
        }
    }
}

// MARK: - Skills / Agent Modes

enum Skill: String, CaseIterable, Identifiable {
    case deepResearch = "deep-research"
    case code = "code"
    case docx = "docx"
    case pdf = "pdf"
    case xlsx = "xlsx"
    case slides = "slides"
    case webSearch = "web-search"
    case agentSwarm = "agent-swarm"
    case creative = "creative"
    case analyst = "analyst"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepResearch: return "Deep Research"
        case .code: return "Code"
        case .docx: return "DOCX"
        case .pdf: return "PDF"
        case .xlsx: return "XLSX"
        case .slides: return "Slides"
        case .webSearch: return "Web Search"
        case .agentSwarm: return "Agent Swarm"
        case .creative: return "Creative"
        case .analyst: return "Analyst"
        }
    }

    var icon: String {
        switch self {
        case .deepResearch: return "magnifyingglass.circle.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .docx: return "doc.text.fill"
        case .pdf: return "doc.richtext.fill"
        case .xlsx: return "tablecells.fill"
        case .slides: return "play.rectangle.fill"
        case .webSearch: return "globe"
        case .agentSwarm: return "network"
        case .creative: return "paintbrush.fill"
        case .analyst: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .deepResearch: return .cyan
        case .code: return .green
        case .docx: return .blue
        case .pdf: return .red
        case .xlsx: return .green
        case .slides: return .orange
        case .webSearch: return .indigo
        case .agentSwarm: return .purple
        case .creative: return .pink
        case .analyst: return .teal
        }
    }

    var systemPrompt: String {
        switch self {
        case .deepResearch:
            return "You are a research agent. Conduct deep analysis of topics, provide structured insights, cite sources where possible, and explore multiple angles. Be thorough and methodical."
        case .code:
            return "You are a senior software developer. Write clean, well-documented code. Follow best practices, explain your reasoning, and provide production-ready solutions. Prefer modern patterns and type safety."
        case .docx:
            return "You help create and edit Word documents. Format responses as structured document content with clear headings, bullet points, and sections suitable for DOCX export."
        case .pdf:
            return "You work with PDF documents. Help analyze, summarize, and extract information from PDF content. Provide structured outputs suitable for document processing workflows."
        case .xlsx:
            return "You analyze spreadsheets and tabular data. Help with data cleaning, formulas, pivot tables, and statistical analysis. Present results in structured table-friendly formats."
        case .slides:
            return "You create presentations. Structure content into slide-friendly sections with titles, bullet points, and speaker notes. Suggest visuals and layouts."
        case .webSearch:
            return "You search for current information on the internet. Provide up-to-date facts, news, and references. Be concise but comprehensive. Always mention when information might be outdated."
        case .agentSwarm:
            return "You are an orchestrator of a group of specialized agents. Break down complex tasks, delegate to hypothetical specialist agents, and synthesize their outputs into cohesive responses."
        case .creative:
            return "You are a creative assistant. Help with writing, storytelling, brainstorming, and creative projects. Be imaginative, inspiring, and supportive."
        case .analyst:
            return "You are a data analyst. Help interpret data, create visualizations, perform statistical analysis, and derive actionable insights. Be precise and data-driven."
        }
    }
}

// MARK: - Attachment Types

enum AttachmentType: String, Codable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case pdf = "pdf"
    case code = "code"
    case unknown = "unknown"

    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .document: return "doc.text.fill"
        case .pdf: return "doc.richtext.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .unknown: return "doc.fill"
        }
    }

    var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .document: return "Document"
        case .pdf: return "PDF"
        case .code: return "Code"
        case .unknown: return "File"
        }
    }
}

// MARK: - SwiftData Models

@Model
class Chat {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var model: String
    var systemPrompt: String?
    var skill: String?
    var isPinned: Bool
    var isArchived: Bool
    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message]?
    @Relationship(deleteRule: .cascade, inverse: \ChatMemory.chat)
    var memories: [ChatMemory]?

    init(title: String = "New Chat", model: String = "openai/gpt-4o", systemPrompt: String? = nil, skill: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.model = model
        self.systemPrompt = systemPrompt
        self.skill = skill
        self.isPinned = false
        self.isArchived = false
    }
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var chat: Chat?
    var attachmentName: String?
    var attachmentType: String?
    var attachmentData: Data?
    var imageBase64: String?
    var isStreaming: Bool
    var isError: Bool
    var metadata: String?
    var artifactType: String?
    var artifactData: String?

    init(role: String, content: String, chat: Chat? = nil, attachmentName: String? = nil, attachmentType: String? = nil, attachmentData: Data? = nil, imageBase64: String? = nil, isStreaming: Bool = false, isError: Bool = false, metadata: String? = nil, artifactType: String? = nil, artifactData: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.chat = chat
        self.attachmentName = attachmentName
        self.attachmentType = attachmentType
        self.attachmentData = attachmentData
        self.imageBase64 = imageBase64
        self.isStreaming = isStreaming
        self.isError = isError
        self.metadata = metadata
        self.artifactType = artifactType
        self.artifactData = artifactData
    }
}

@Model
class ChatMemory {
    @Attribute(.unique) var id: UUID
    var content: String
    var embedding: Data?
    var timestamp: Date
    var memoryType: String
    var chat: Chat?

    init(content: String, embedding: Data? = nil, memoryType: String = "short", chat: Chat? = nil) {
        self.id = UUID()
        self.content = content
        self.embedding = embedding
        self.timestamp = Date()
        self.memoryType = memoryType
        self.chat = chat
    }
}

@Model
class MCPServer {
    @Attribute(.unique) var id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var config: String?

    init(name: String, url: String, isEnabled: Bool = false, config: String? = nil) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.config = config
    }
}

// MARK: - OpenRouter API Models

struct OpenRouterModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let contextLength: Int?
    let pricing: ModelPricing?

    init(name: String, displayName: String, description: String, contextLength: Int? = nil, pricing: ModelPricing? = nil) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.contextLength = contextLength
        self.pricing = pricing
    }
}

struct ModelPricing: Codable {
    let prompt: Double?
    let completion: Double?
}

let availableModels: [OpenRouterModel] = [
    OpenRouterModel(name: "openai/gpt-4o", displayName: "GPT-4o", description: "OpenAI", contextLength: 128000),
    OpenRouterModel(name: "anthropic/claude-3.5-sonnet", displayName: "Claude 3.5 Sonnet", description: "Anthropic", contextLength: 200000),
    OpenRouterModel(name: "anthropic/claude-3-opus", displayName: "Claude 3 Opus", description: "Anthropic", contextLength: 200000),
    OpenRouterModel(name: "meta-llama/llama-3.1-70b-instruct", displayName: "Llama 3.1 70B", description: "Meta", contextLength: 128000),
    OpenRouterModel(name: "meta-llama/llama-3.1-405b-instruct", displayName: "Llama 3.1 405B", description: "Meta", contextLength: 128000),
    OpenRouterModel(name: "google/gemini-1.5-pro", displayName: "Gemini 1.5 Pro", description: "Google", contextLength: 2000000),
    OpenRouterModel(name: "mistralai/mistral-large", displayName: "Mistral Large", description: "Mistral AI", contextLength: 128000),
    OpenRouterModel(name: "openai/gpt-4o-mini", displayName: "GPT-4o Mini", description: "OpenAI", contextLength: 128000),
    OpenRouterModel(name: "deepseek/deepseek-chat", displayName: "DeepSeek Chat", description: "DeepSeek", contextLength: 64000),
    OpenRouterModel(name: "qwen/qwen-2.5-72b-instruct", displayName: "Qwen 2.5 72B", description: "Alibaba", contextLength: 128000),
    OpenRouterModel(name: "x-ai/grok-beta", displayName: "Grok Beta", description: "xAI", contextLength: 128000),
    OpenRouterModel(name: "perplexity/llama-3.1-sonar-large-128k-online", displayName: "Sonar Large", description: "Perplexity", contextLength: 128000)
]

let fallbackModels2026: [OpenRouterModel] = [
    OpenRouterModel(name: "openai/gpt-5", displayName: "GPT-5", description: "OpenAI", contextLength: 256000),
    OpenRouterModel(name: "openai/gpt-5-mini", displayName: "GPT-5 Mini", description: "OpenAI", contextLength: 256000),
    OpenRouterModel(name: "openai/gpt-5.2", displayName: "GPT-5.2", description: "OpenAI", contextLength: 512000),
    OpenRouterModel(name: "openai/gpt-5.3-codex", displayName: "GPT-5.3 Codex", description: "OpenAI", contextLength: 512000),
    OpenRouterModel(name: "anthropic/claude-opus-4.7", displayName: "Claude Opus 4.7", description: "Anthropic", contextLength: 500000),
    OpenRouterModel(name: "anthropic/claude-sonnet-4.6", displayName: "Claude Sonnet 4.6", description: "Anthropic", contextLength: 300000),
    OpenRouterModel(name: "anthropic/claude-haiku-4.5", displayName: "Claude Haiku 4.5", description: "Anthropic", contextLength: 200000),
    OpenRouterModel(name: "google/gemini-3.1-pro", displayName: "Gemini 3.1 Pro", description: "Google", contextLength: 4000000),
    OpenRouterModel(name: "google/gemini-3.0-pro", displayName: "Gemini 3.0 Pro", description: "Google", contextLength: 4000000),
    OpenRouterModel(name: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash", description: "Google", contextLength: 1000000),
    OpenRouterModel(name: "x-ai/grok-4", displayName: "Grok 4", description: "xAI", contextLength: 256000),
    OpenRouterModel(name: "x-ai/grok-4.1-thinking", displayName: "Grok 4.1 Thinking", description: "xAI", contextLength: 256000),
    OpenRouterModel(name: "deepseek/deepseek-chat-v3.1", displayName: "DeepSeek Chat v3.1", description: "DeepSeek", contextLength: 128000),
    OpenRouterModel(name: "deepseek/deepseek-r2", displayName: "DeepSeek R2", description: "DeepSeek", contextLength: 128000),
    OpenRouterModel(name: "meta-llama/llama-4-maverick", displayName: "Llama 4 Maverick", description: "Meta", contextLength: 256000),
    OpenRouterModel(name: "meta-llama/llama-4-scout", displayName: "Llama 4 Scout", description: "Meta", contextLength: 128000),
    OpenRouterModel(name: "qwen/qwen3-30b-a3b-thinking", displayName: "Qwen3 30B A3B Thinking", description: "Alibaba", contextLength: 128000),
    OpenRouterModel(name: "qwen/qwen3-max", displayName: "Qwen3 Max", description: "Alibaba", contextLength: 256000),
    OpenRouterModel(name: "moonshotai/kimi-k2-0905", displayName: "Kimi K2", description: "Moonshot AI", contextLength: 256000),
    OpenRouterModel(name: "mistralai/mistral-medium-3.1", displayName: "Mistral Medium 3.1", description: "Mistral AI", contextLength: 128000)
]

// MARK: - API Request/Response Models

struct OpenRouterRequest: Codable {
    let model: String
    let messages: [OpenRouterMessage]
    let temperature: Double?
    let max_tokens: Int?
    let stream: Bool?
    let tools: [ToolDefinition]?
    let tool_choice: String?

    init(model: String, messages: [OpenRouterMessage], temperature: Double? = 0.7, maxTokens: Int? = nil, stream: Bool? = false, tools: [ToolDefinition]? = nil, toolChoice: String? = nil) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.max_tokens = maxTokens
        self.stream = stream
        self.tools = tools
        self.tool_choice = toolChoice
    }
}

struct OpenRouterMessage: Codable {
    let role: String
    let content: MessageContent

    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }

    init(role: String, content: [ContentPart]) {
        self.role = role
        self.content = .parts(content)
    }
}

enum MessageContent: Codable {
    case text(String)
    case parts([ContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .parts(let parts):
            try container.encode(parts)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
        } else if let parts = try? container.decode([ContentPart].self) {
            self = .parts(parts)
        } else {
            self = .text("")
        }
    }
}

struct ContentPart: Codable {
    let type: String
    let text: String?
    let image_url: ImageURLData?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case image_url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(image_url, forKey: .image_url)
    }
}

struct ImageURLData: Codable {
    let url: String
    let detail: String?

    init(url: String, detail: String? = "auto") {
        self.url = url
        self.detail = detail
    }
}

struct OpenRouterResponse: Codable {
    let choices: [Choice]?
    let error: OpenRouterError?
    let usage: UsageInfo?
}

struct Choice: Codable {
    let message: ResponseMessage?
    let delta: DeltaMessage?
    let finish_reason: String?
    let index: Int?
}

struct ResponseMessage: Codable {
    let content: String?
    let role: String?
    let tool_calls: [ToolCall]?
}

struct DeltaMessage: Codable {
    let content: String?
    let role: String?
    let tool_calls: [ToolCall]?
}

struct ToolCall: Codable {
    let id: String?
    let type: String?
    let function: ToolFunction?
    let index: Int?
}

struct ToolFunction: Codable {
    let name: String?
    let arguments: String?
}

struct ToolDefinition: Codable {
    let type: String
    let function: ToolFunctionDefinition
}

struct ToolFunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: ToolParameters
}

struct ToolParameters: Codable {
    let type: String
    let properties: [String: ToolProperty]?
    let required: [String]?
}

struct ToolProperty: Codable {
    let type: String
    let description: String?
    let enum_values: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enum_values = "enum"
    }
}

struct UsageInfo: Codable {
    let prompt_tokens: Int?
    let completion_tokens: Int?
    let total_tokens: Int?
}

struct OpenRouterError: Codable {
    let message: String?
    let type: String?
    let code: String?
}

struct ModelsResponse: Codable {
    let data: [ModelInfo]
    let object: String?
}

struct ModelInfo: Codable {
    let id: String
    let name: String?
    let description: String?
    let context_length: Int?
}

struct TranscriptionResponse: Codable {
    let text: String?
}

// MARK: - Artifact Types

enum ArtifactType: String {
    case code = "code"
    case image = "image"
    case chart = "chart"
    case table = "table"
    case document = "document"
    case svg = "svg"
    case mermaid = "mermaid"
}

// MARK: - Graphite Theme

struct GraphiteTheme {
    static let background = Color(#colorLiteral(red: 0.0588, green: 0.0588, blue: 0.0627, alpha: 1))
    static let surface = Color(#colorLiteral(red: 0.0902, green: 0.0902, blue: 0.0941, alpha: 1))
    static let panel = Color(#colorLiteral(red: 0.1294, green: 0.1294, blue: 0.1373, alpha: 1))
    static let panelHover = Color(#colorLiteral(red: 0.1608, green: 0.1608, blue: 0.1686, alpha: 1))
    static let border = Color(#colorLiteral(red: 0.2, green: 0.2, blue: 0.2157, alpha: 1))
    static let accent = Color(#colorLiteral(red: 0.6784, green: 0.6784, blue: 0.7020, alpha: 1))
    static let accentBright = Color(#colorLiteral(red: 0.8510, green: 0.8510, blue: 0.8706, alpha: 1))
    static let secondaryText = Color(#colorLiteral(red: 0.4588, green: 0.4588, blue: 0.4784, alpha: 1))
    static let tertiaryText = Color(#colorLiteral(red: 0.3294, green: 0.3294, blue: 0.3490, alpha: 1))
    static let success = Color(#colorLiteral(red: 0.2980, green: 0.6863, blue: 0.3137, alpha: 1))
    static let warning = Color(#colorLiteral(red: 0.9569, green: 0.7608, blue: 0.2667, alpha: 1))
    static let error = Color(#colorLiteral(red: 0.9373, green: 0.3255, blue: 0.3137, alpha: 1))
    static let info = Color(#colorLiteral(red: 0.2588, green: 0.6471, blue: 0.9608, alpha: 1))

    static let gradientStart = Color(#colorLiteral(red: 0.1098, green: 0.1098, blue: 0.1176, alpha: 1))
    static let gradientEnd = Color(#colorLiteral(red: 0.0588, green: 0.0588, blue: 0.0627, alpha: 1))

    static func glassMaterial(opacity: Double = 0.7) -> some View {
        Color.white.opacity(opacity * 0.05)
    }
}

// MARK: - View Modifiers

struct GraphiteButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? GraphiteTheme.accent.opacity(configuration.isPressed ? 0.7 : 1.0) : GraphiteTheme.panel.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundStyle(isPrimary ? GraphiteTheme.background : .white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GraphiteCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GraphiteTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(GraphiteTheme.border.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func graphiteCard() -> some View {
        modifier(GraphiteCardStyle())
    }
}

// MARK: - Animation Extensions

extension Animation {
    static func graphiteSpring() -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    }

    static func graphiteEase() -> Animation {
        .easeInOut(duration: 0.3)
    }
}
