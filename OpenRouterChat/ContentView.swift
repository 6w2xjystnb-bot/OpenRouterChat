import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit

// MARK: - Main Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.createdAt, order: .reverse) private var chats: [Chat]

    @State private var selectedChat: Chat?
    @State private var selectedTab: Tab = .chats
    @State private var showingNewChat = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all

    var filteredChats: [Chat] {
        let active = chats.filter { !$0.isArchived }
        if searchText.isEmpty { return active }
        return active.filter { chat in
            let titleMatch = chat.title.localizedCaseInsensitiveContains(searchText)
            let messageMatch = chat.messages?.contains(where: {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }) ?? false
            return titleMatch || messageMatch
        }
    }

    var pinnedChats: [Chat] {
        filteredChats.filter { $0.isPinned }
    }

    var unpinnedChats: [Chat] {
        filteredChats.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedChat) {
            ModelSelectorSection()

            Section {
                Button(action: { showingNewChat = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(GraphiteTheme.accentBright)
                        Text("New Chat")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(.white)
                }
                .listRowBackground(GraphiteTheme.panel.opacity(0.5))
            }

            if !pinnedChats.isEmpty {
                Section {
                    ForEach(pinnedChats) { chat in
                        ChatRow(chat: chat, isSelected: selectedChat?.id == chat.id)
                            .tag(chat)
                    }
                } header: {
                    Text("Pinned")
                        .font(.caption)
                        .foregroundStyle(GraphiteTheme.tertiaryText)
                }
            }

            Section {
                ForEach(unpinnedChats) { chat in
                    ChatRow(chat: chat, isSelected: selectedChat?.id == chat.id)
                        .tag(chat)
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    chat.isPinned.toggle()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(GraphiteTheme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    if selectedChat?.id == chat.id {
                                        selectedChat = nil
                                    }
                                    modelContext.delete(chat)
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("Recent Chats")
                    .font(.caption)
                    .foregroundStyle(GraphiteTheme.tertiaryText)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(GraphiteTheme.background)
        .navigationTitle("Chats")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search chats...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .foregroundStyle(GraphiteTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatSheet(selectedChat: $selectedChat)
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if let chat = selectedChat {
            ChatDetailView(chat: chat)
                .id(chat.id)
        } else {
            EmptyStateView()
        }
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let chat: Chat
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Model icon
            ZStack {
                Circle()
                    .fill(modelColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: modelIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(modelColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(GraphiteTheme.accent)
                    }
                    Text(displayModelName)
                        .font(.caption2)
                        .foregroundStyle(GraphiteTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let lastMessage = chat.messages?.sorted(by: { $0.timestamp < $1.timestamp }).last {
                Text(timeAgo(lastMessage.timestamp))
                    .font(.caption2)
                    .foregroundStyle(GraphiteTheme.tertiaryText)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(isSelected ? GraphiteTheme.panelHover : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var displayModelName: String {
        let parts = chat.model.split(separator: "/")
        return parts.last.map(String.init) ?? chat.model
    }

    private var modelIcon: String {
        if chat.model.contains("claude") { return "sparkles" }
        if chat.model.contains("gpt") { return "brain" }
        if chat.model.contains("gemini") { return "diamond" }
        if chat.model.contains("llama") { return "leaf" }
        if chat.model.contains("deepseek") { return "flame" }
        return "cpu"
    }

    private var modelColor: Color {
        if chat.model.contains("claude") { return .orange }
        if chat.model.contains("gpt") { return .green }
        if chat.model.contains("gemini") { return .blue }
        if chat.model.contains("llama") { return .teal }
        if chat.model.contains("deepseek") { return .purple }
        return GraphiteTheme.accent
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Model Selector Section

struct ModelSelectorSection: View {
    @AppStorage("global_selected_model") private var globalModel = "openai/gpt-4o"
    @State private var showingModelSheet = false

    var displayModelName: String {
        let parts = globalModel.split(separator: "/")
        return parts.last.map(String.init) ?? globalModel
    }

    var body: some View {
        Button(action: { showingModelSheet = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GraphiteTheme.panel)
                        .frame(width: 40, height: 40)
                    Image(systemName: "cpu")
                        .font(.title3)
                        .foregroundStyle(GraphiteTheme.accentBright)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Model")
                        .font(.caption)
                        .foregroundStyle(GraphiteTheme.secondaryText)
                    Text(displayModelName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(GraphiteTheme.tertiaryText)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(GraphiteTheme.surface)
        .sheet(isPresented: $showingModelSheet) {
            ModelSelectorSheet(selectedModel: $globalModel)
        }
    }
}

// MARK: - Model Selector Sheet

struct ModelSelectorSheet: View {
    @Binding var selectedModel: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("openrouter_api_key") private var apiKey = ""
    @AppStorage("api_base_url") private var apiBaseURL = APIProvider.openrouter.baseURL
    @State private var searchQuery = ""
    @State private var dynamicModels: [OpenRouterModel] = []
    @State private var isLoadingModels = false
    @State private var usingFallback = false
    @State private var selectedCategory: ModelCategory = .all

    enum ModelCategory: String, CaseIterable {
        case all = "All"
        case openai = "OpenAI"
        case anthropic = "Anthropic"
        case google = "Google"
        case meta = "Meta"
        case other = "Other"
    }

    private var displayModels: [OpenRouterModel] {
        let base = dynamicModels.isEmpty ? (usingFallback ? fallbackModels2026 : availableModels) : dynamicModels
        var filtered = base

        if selectedCategory != .all {
            filtered = filtered.filter { model in
                switch selectedCategory {
                case .openai: return model.name.contains("openai")
                case .anthropic: return model.name.contains("anthropic")
                case .google: return model.name.contains("google")
                case .meta: return model.name.contains("meta")
                case .other: return !model.name.contains("openai") && !model.name.contains("anthropic") && !model.name.contains("google") && !model.name.contains("meta")
                default: return true
                }
            }
        }

        if searchQuery.isEmpty { return filtered }
        return filtered.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ModelCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Text(category.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? GraphiteTheme.accent : GraphiteTheme.panel)
                                    .foregroundStyle(selectedCategory == category ? GraphiteTheme.background : .white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if isLoadingModels {
                    ProgressView()
                        .padding()
                }

                List {
                    ForEach(displayModels) { model in
                        ModelRow(model: model, isSelected: selectedModel == model.name) {
                            withAnimation(.graphiteSpring()) {
                                selectedModel = model.name
                            }
                            dismiss()
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(GraphiteTheme.background)
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search models...")
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(GraphiteTheme.accent)
                }
            }
            .task {
                await loadModels()
            }
        }
    }

    private func loadModels() async {
        isLoadingModels = true
        usingFallback = false
        defer { isLoadingModels = false }

        do {
            let modelIDs = try await OpenRouterService.shared.fetchModels(baseURL: apiBaseURL, apiKey: apiKey)
            dynamicModels = modelIDs.map { id in
                let parts = id.split(separator: "/")
                let provider = parts.first.map(String.init) ?? "Unknown"
                let name = parts.last.map(String.init) ?? id
                return OpenRouterModel(name: id, displayName: name, description: provider)
            }
        } catch {
            usingFallback = true
            dynamicModels = []
        }
    }
}

struct ModelRow: View {
    let model: OpenRouterModel
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? GraphiteTheme.accent.opacity(0.2) : GraphiteTheme.panel)
                        .frame(width: 40, height: 40)
                    Image(systemName: modelIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? GraphiteTheme.accentBright : GraphiteTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(model.description)
                            .font(.caption)
                            .foregroundStyle(GraphiteTheme.secondaryText)
                        if let context = model.contextLength {
                            Text("\(context / 1000)K")
                                .font(.caption2)
                                .foregroundStyle(GraphiteTheme.tertiaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GraphiteTheme.panel)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(GraphiteTheme.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? GraphiteTheme.panelHover.opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var modelIcon: String {
        if model.name.contains("claude") { return "sparkles" }
        if model.name.contains("gpt") { return "brain" }
        if model.name.contains("gemini") { return "diamond" }
        if model.name.contains("llama") { return "leaf" }
        if model.name.contains("deepseek") { return "flame" }
        return "cpu"
    }
}

// MARK: - Chat Detail View

struct ChatDetailView: View {
    let chat: Chat
    @Environment(\.modelContext) private var modelContext
    @AppStorage("openrouter_api_key") private var apiKey = ""
    @AppStorage("api_base_url") private var apiBaseURL = APIProvider.openrouter.baseURL
    @AppStorage("use_streaming") private var useStreaming = true
    @State private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showingAttachmentMenu = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingDocumentPicker = false
    @State private var showingCamera = false
    @State private var pendingImageBase64: String?
    @State private var pendingAttachmentName: String?
    @State private var pendingAttachmentContent: String?
    @State private var pendingAttachmentType: AttachmentType?
    @State private var showingAgentPanel = false
    @State private var showingSkillsMenu = false
    @State private var scrollProxy: ScrollViewProxy?

    var sortedMessages: [Message] {
        chat.messages?.sorted(by: { $0.timestamp < $1.timestamp }) ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedMessages) { message in
                        EnhancedMessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: message.role == "user" ? .trailing : .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if viewModel.isLoading && !viewModel.isStreaming {
                        LoadingIndicator()
                            .id("loading")
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .onChange(of: sortedMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if loading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.streamBuffer) { _, _ in
                if let last = sortedMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
        .background(GraphiteTheme.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                AttachmentPreviewBar(
                    imageBase64: $pendingImageBase64,
                    attachmentName: $pendingAttachmentName,
                    attachmentContent: $pendingAttachmentContent,
                    attachmentType: $pendingAttachmentType
                )

                if showingAgentPanel {
                    AgentPanel(viewModel: viewModel, chat: chat)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                InputBar(
                    messageText: $messageText,
                    isInputFocused: _isInputFocused,
                    viewModel: viewModel,
                    onSend: sendMessage,
                    onAttachment: { showingAttachmentMenu = true },
                    onAgent: { withAnimation { showingAgentPanel.toggle() } }
                )
            }
            .background(
                GraphiteTheme.background
                    .overlay(
                        LinearGradient(
                            colors: [.clear, GraphiteTheme.background.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(Skill.allCases) { skill in
                        Button(action: {
                            chat.systemPrompt = skill.systemPrompt
                            chat.skill = skill.rawValue
                            try? modelContext.save()
                        }) {
                            Label(skill.displayName, systemImage: skill.icon)
                        }
                    }
                    if chat.systemPrompt != nil {
                        Divider()
                        Button(action: {
                            chat.systemPrompt = nil
                            chat.skill = nil
                            try? modelContext.save()
                        }) {
                            Label("Clear Skill", systemImage: "xmark")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let skillRaw = chat.skill, let skill = Skill(rawValue: skillRaw) {
                            Image(systemName: skill.icon)
                                .foregroundStyle(skill.color)
                        } else {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(GraphiteTheme.accent)
                        }
                    }
                }
            }
        }
        .photosPicker(isPresented: $showingAttachmentMenu, selection: $selectedImage, matching: .images)
        .onChange(of: selectedImage) { _, item in
            Task {
                await loadImage(from: item)
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                loadDocument(from: url)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = sortedMessages.last {
            withAnimation(.graphiteEase()) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        var text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingImageBase64 != nil || pendingAttachmentContent != nil else { return }

        if let attachmentContent = pendingAttachmentContent, let attachmentName = pendingAttachmentName {
            text = "[Attachment: \(attachmentName)]\n\n\(attachmentContent)\n\n\(text)"
        }

        let imgB64 = pendingImageBase64

        messageText = ""
        pendingAttachmentName = nil
        pendingAttachmentContent = nil
        pendingAttachmentType = nil
        pendingImageBase64 = nil
        isInputFocused = true

        Task {
            if useStreaming {
                await viewModel.sendStreamingMessage(text, chat: chat, modelContext: modelContext, apiKey: apiKey, baseURL: apiBaseURL, imageBase64: imgB64)
            } else {
                await viewModel.sendMessage(text, chat: chat, modelContext: modelContext, apiKey: apiKey, baseURL: apiBaseURL, imageBase64: imgB64)
            }

            if sortedMessages.count == 2 {
                await viewModel.generateChatTitle(for: chat, modelContext: modelContext, apiKey: apiKey, baseURL: apiBaseURL)
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let base64 = data.base64EncodedString()
                await MainActor.run {
                    pendingImageBase64 = base64
                    pendingAttachmentType = .image
                }
            }
        } catch {
            viewModel.errorMessage = "Failed to load image: \(error.localizedDescription)"
        }
    }

    private func loadDocument(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        do {
            let data = try Data(contentsOf: url)
            let type: AttachmentType

            if ["txt", "md", "swift", "py", "js", "json", "html", "css", "xml"].contains(ext) {
                type = .code
                if let text = String(data: data, encoding: .utf8) {
                    pendingAttachmentName = fileName
                    pendingAttachmentContent = text
                    pendingAttachmentType = type
                }
            } else if ext == "pdf" {
                type = .pdf
                pendingAttachmentName = fileName
                pendingAttachmentContent = "[PDF: \(data.count) bytes]"
                pendingAttachmentType = type
            } else if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) {
                type = .image
                pendingImageBase64 = data.base64EncodedString()
                pendingAttachmentType = type
            } else if ["mp4", "mov", "avi", "mkv"].contains(ext) {
                type = .video
                pendingAttachmentName = fileName
                pendingAttachmentContent = "[Video: \(data.count) bytes]"
                pendingAttachmentType = type
            } else if ["mp3", "wav", "m4a", "aac", "ogg"].contains(ext) {
                type = .audio
                pendingAttachmentName = fileName
                pendingAttachmentContent = "[Audio: \(data.count) bytes]"
                pendingAttachmentType = type
            } else {
                type = .document
                pendingAttachmentName = fileName
                pendingAttachmentContent = "[File: \(data.count) bytes]"
                pendingAttachmentType = type
            }
        } catch {
            viewModel.errorMessage = "Failed to load document: \(error.localizedDescription)"
        }
    }
}

// MARK: - Enhanced Message Bubble

struct EnhancedMessageBubble: View {
    let message: Message
    @State private var isHovered = false
    @State private var showingActions = false

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Attachment indicator
                if let attachmentName = message.attachmentName, let typeStr = message.attachmentType, let type = AttachmentType(rawValue: typeStr) {
                    AttachmentBadge(name: attachmentName, type: type)
                }

                // Image display
                if let imgB64 = message.imageBase64, let data = Data(base64Encoded: imgB64), let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .frame(maxWidth: 280, maxHeight: 280)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(GraphiteTheme.border, lineWidth: 1)
                        )
                }

                // Content with artifacts
                MessageContentView(message: message)

                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(GraphiteTheme.tertiaryText)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 4)

            if !isUser { Spacer(minLength: 40) }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.graphiteEase()) {
                showingActions.toggle()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Message Content View

struct MessageContentView: View {
    let message: Message
    @State private var copied = false

    var body: some View {
        let segments = parseContent(message.content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<segments.count, id: \.self) { index in
                switch segments[index] {
                case .text(let text):
                    if !text.isEmpty {
                        Text(formattedText(text))
                            .textSelection(.enabled)
                            .padding(14)
                            .background(
                                message.role == "user"
                                    ? GraphiteTheme.accent.opacity(0.15)
                                    : GraphiteTheme.panel
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        message.role == "user"
                                            ? GraphiteTheme.accent.opacity(0.3)
                                            : GraphiteTheme.border,
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(.white)
                    }

                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)

                case .image(let base64):
                    if let data = Data(base64Encoded: base64), let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: 250, maxHeight: 250)
                    }

                case .artifact(let type, let data):
                    ArtifactView(type: type, data: data)
                }
            }
        }
    }

    private func formattedText(_ text: String) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(
                markdown: text,
                options: options
            )
        } catch {
            return AttributedString(text)
        }
    }
}

// MARK: - Artifact View

struct ArtifactView: View {
    let type: String
    let data: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: artifactIcon)
                    .foregroundStyle(GraphiteTheme.accent)
                Text(artifactTitle)
                    .font(.caption.bold())
                    .foregroundStyle(GraphiteTheme.accentBright)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(GraphiteTheme.secondaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(data)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GraphiteTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .background(GraphiteTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GraphiteTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var artifactIcon: String {
        switch type {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "chart": return "chart.bar"
        case "table": return "tablecells"
        case "svg": return "paintbrush"
        case "mermaid": return "arrow.triangle.branch"
        default: return "doc"
        }
    }

    private var artifactTitle: String {
        switch type {
        case "code": return "Code Artifact"
        case "chart": return "Chart"
        case "table": return "Data Table"
        case "svg": return "SVG Graphic"
        case "mermaid": return "Diagram"
        default: return "Artifact"
        }
    }
}

// MARK: - Attachment Badge

struct AttachmentBadge: View {
    let name: String
    let type: AttachmentType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.caption)
            Text(name)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(GraphiteTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(GraphiteTheme.accent.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(GraphiteTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                    Text(language ?? "code")
                        .font(.caption.bold())
                }
                .foregroundStyle(GraphiteTheme.secondaryText)

                Spacer()

                Button(action: {
                    UIPasteboard.general.string = code
                    withAnimation {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            copied = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(copied ? "Copied" : "Copy")
                            .font(.caption)
                    }
                    .foregroundStyle(copied ? GraphiteTheme.success : GraphiteTheme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GraphiteTheme.surface)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(GraphiteTheme.accentBright)
                    .padding(14)
            }
        }
        .background(GraphiteTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GraphiteTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    @ObservedObject var viewModel: ChatViewModel
    let onSend: () -> Void
    let onAttachment: () -> Void
    let onAgent: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Attachment button
            Menu {
                Button(action: onAttachment) {
                    Label("Photo", systemImage: "photo")
                }
                Button(action: onAttachment) {
                    Label("Camera", systemImage: "camera")
                }
                Button(action: {}) {
                    Label("Video", systemImage: "video")
                }
                Button(action: {}) {
                    Label("Document", systemImage: "doc")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(GraphiteTheme.accent)
                    .frame(width: 40, height: 40)
            }

            // Text input
            HStack(spacing: 8) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .foregroundStyle(.white)
                    .focused($isInputFocused)

                if !messageText.isEmpty {
                    Button(action: { messageText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(GraphiteTheme.tertiaryText)
                    }
                    .transition(.scale)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GraphiteTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(GraphiteTheme.border, lineWidth: 1)
            )

            // Voice / Send button
            if viewModel.isRecording {
                RecordingButton(duration: viewModel.recordingDuration) {
                    viewModel.stopRecording()
                }
            } else if messageText.isEmpty {
                Button(action: {
                    viewModel.startRecording()
                }) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(GraphiteTheme.accent)
                        .frame(width: 40, height: 40)
                }
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(GraphiteTheme.accentBright)
                        .frame(width: 40, height: 40)
                }
                .disabled(viewModel.isLoading)
                .transition(.scale)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Recording Button

struct RecordingButton: View {
    let duration: TimeInterval
    let onStop: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button(action: onStop) {
            ZStack {
                Circle()
                    .fill(GraphiteTheme.error.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.5 : 1.0)

                Circle()
                    .fill(GraphiteTheme.error)
                    .frame(width: 14, height: 14)
            }
        }
        .overlay(
            Text(String(format: "%.1f", duration))
                .font(.caption2)
                .foregroundStyle(GraphiteTheme.error)
                .offset(y: -28)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Attachment Preview Bar

struct AttachmentPreviewBar: View {
    @Binding var imageBase64: String?
    @Binding var attachmentName: String?
    @Binding var attachmentContent: String?
    @Binding var attachmentType: AttachmentType?

    var body: some View {
        VStack(spacing: 4) {
            if let imgB64 = imageBase64, let data = Data(base64Encoded: imgB64), let uiImage = UIImage(data: data) {
                HStack(spacing: 10) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Image attached")
                        .font(.caption)
                        .foregroundStyle(GraphiteTheme.secondaryText)

                    Spacer()

                    Button(action: { imageBase64 = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(GraphiteTheme.tertiaryText)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            if let name = attachmentName, let type = attachmentType {
                HStack(spacing: 10) {
                    Image(systemName: type.icon)
                        .foregroundStyle(GraphiteTheme.accent)
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(GraphiteTheme.secondaryText)
                        .lineLimit(1)

                    Spacer()

                    Button(action: {
                        attachmentName = nil
                        attachmentContent = nil
                        attachmentType = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(GraphiteTheme.tertiaryText)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Agent Panel

struct AgentPanel: View {
    @ObservedObject var viewModel: ChatViewModel
    let chat: Chat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(GraphiteTheme.accent)
                Text("Agent Swarm")
                    .font(.caption.bold())
                    .foregroundStyle(GraphiteTheme.accentBright)
                Spacer()
            }

            if viewModel.activeAgents.isEmpty {
                Text("Agents ready to assist")
                    .font(.caption)
                    .foregroundStyle(GraphiteTheme.secondaryText)
            } else {
                ForEach(viewModel.activeAgents) { agent in
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(agent.name)
                            .font(.caption)
                            .foregroundStyle(GraphiteTheme.secondaryText)
                        Spacer()
                    }
                }
            }

            if !viewModel.agentResults.isEmpty {
                Divider()
                    .background(GraphiteTheme.border)
                ForEach(viewModel.agentResults) { result in
                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(result.isSuccess ? GraphiteTheme.success : GraphiteTheme.error)
                        Text(result.agentName)
                            .font(.caption)
                            .foregroundStyle(GraphiteTheme.secondaryText)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(GraphiteTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GraphiteTheme.accent.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(GraphiteTheme.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(GraphiteTheme.warning)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(GraphiteTheme.secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GraphiteTheme.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(GraphiteTheme.warning.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -10)
        .onAppear {
            withAnimation(.graphiteEase()) {
                isVisible = true
            }
        }
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(GraphiteTheme.accent)
                        .opacity(isAnimating ? 1.0 : 0.3)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(GraphiteTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(GraphiteTheme.border, lineWidth: 1)
            )
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(GraphiteTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(GraphiteTheme.accent)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }

            VStack(spacing: 8) {
                Text("OpenRouter Chat")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Select a chat or create a new one")
                    .font(.subheadline)
                    .foregroundStyle(GraphiteTheme.secondaryText)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GraphiteTheme.background)
    }
}

// MARK: - New Chat Sheet

struct NewChatSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedChat: Chat?
    @AppStorage("global_selected_model") private var globalModel = "openai/gpt-4o"
    @State private var selectedSkill: Skill?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(GraphiteTheme.accent.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(GraphiteTheme.accent)
                }

                VStack(spacing: 6) {
                    Text("Start a New Chat")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Model: \(displayModelName)")
                        .font(.subheadline)
                        .foregroundStyle(GraphiteTheme.secondaryText)
                }

                // Skill selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Skill.allCases) { skill in
                            SkillButton(skill: skill, isSelected: selectedSkill?.id == skill.id) {
                                withAnimation {
                                    selectedSkill = selectedSkill?.id == skill.id ? nil : skill
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button("Create Chat") {
                    let chat = Chat(
                        title: "New Chat",
                        model: globalModel,
                        systemPrompt: selectedSkill?.systemPrompt,
                        skill: selectedSkill?.rawValue
                    )
                    modelContext.insert(chat)
                    try? modelContext.save()
                    selectedChat = chat
                    dismiss()
                }
                .buttonStyle(GraphiteButtonStyle(isPrimary: true))
                .controlSize(.large)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GraphiteTheme.background)
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(GraphiteTheme.accent)
                }
            }
        }
    }

    private var displayModelName: String {
        let parts = globalModel.split(separator: "/")
        return parts.last.map(String.init) ?? globalModel
    }
}

struct SkillButton: View {
    let skill: Skill
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: skill.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : skill.color)
                Text(skill.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : GraphiteTheme.secondaryText)
            }
            .frame(width: 80, height: 70)
            .background(isSelected ? skill.color : GraphiteTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? skill.color : GraphiteTheme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.graphiteSpring(), value: isSelected)
    }
}

// MARK: - App Settings View

struct AppSettingsView: View {
    @AppStorage("openrouter_api_key") private var apiKey = ""
    @AppStorage("selected_provider") private var selectedProvider = APIProvider.openrouter.rawValue
    @AppStorage("api_base_url") private var apiBaseURL = APIProvider.openrouter.baseURL
    @AppStorage("use_streaming") private var useStreaming = true
    @AppStorage("use_local_whisper") private var useLocalWhisper = false
    @AppStorage("mcp_web_search") private var mcpWebSearch = false
    @AppStorage("mcp_code_interpreter") private var mcpCodeInterpreter = false
    @AppStorage("mcp_file_manager") private var mcpFileManager = false
    @Environment(\.dismiss) private var dismiss

    private var currentProvider: APIProvider {
        APIProvider(rawValue: selectedProvider) ?? .openrouter
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(APIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    if currentProvider == .custom {
                        TextField("Custom Base URL", text: $apiBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text(apiBaseURL)
                            .font(.caption)
                            .foregroundStyle(GraphiteTheme.secondaryText)
                    }
                } header: {
                    Text("API Provider")
                }

                Section {
                    SecureField("Enter API Key", text: $apiKey)
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Your key is stored securely on device")
                        .font(.caption)
                        .foregroundStyle(GraphiteTheme.tertiaryText)
                }

                Section {
                    Toggle("Streaming Responses", isOn: $useStreaming)
                    Toggle("Local Whisper (On-Device)", isOn: $useLocalWhisper)
                } header: {
                    Text("Features")
                }

                Section {
                    Toggle("Web Search", isOn: $mcpWebSearch)
                    Toggle("Code Interpreter", isOn: $mcpCodeInterpreter)
                    Toggle("File Manager", isOn: $mcpFileManager)
                } header: {
                    Text("MCP Connections")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(GraphiteTheme.secondaryText)
                    }
                    HStack {
                        Text("iOS")
                        Spacer()
                        Text("26+")
                            .foregroundStyle(GraphiteTheme.secondaryText)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(GraphiteTheme.accent)
                }
            }
            .onChange(of: selectedProvider) { _, newValue in
                if let provider = APIProvider(rawValue: newValue), provider != .custom {
                    apiBaseURL = provider.baseURL
                }
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            .data, .plainText, .pdf, .image, .movie, .audio,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "swift") ?? .plainText,
            UTType(filenameExtension: "py") ?? .plainText,
            UTType(filenameExtension: "js") ?? .plainText,
            UTType(filenameExtension: "json") ?? .plainText
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - Message Segment Parser

enum MessageSegment {
    case text(String)
    case code(language: String?, code: String)
    case image(base64: String)
    case artifact(type: String, data: String)
}

func parseContent(_ content: String) -> [MessageSegment] {
    var segments: [MessageSegment] = []

    // Parse code blocks
    let codePattern = "```([\\w]*)\\n?([\\s\\S]*?)```"
    guard let codeRegex = try? NSRegularExpression(pattern: codePattern, options: []) else {
        segments.append(.text(content))
        return segments
    }

    let nsRange = NSRange(content.startIndex..., in: content)
    let codeMatches = codeRegex.matches(in: content, options: [], range: nsRange)

    var lastEnd = content.startIndex
    for match in codeMatches {
        let matchRange = Range(match.range, in: content)!
        if lastEnd < matchRange.lowerBound {
            let textSegment = String(content[lastEnd..<matchRange.lowerBound])
            segments.append(contentsOf: parseImagesAndArtifacts(textSegment))
        }
        let langRange = match.range(at: 1)
        let codeRange = match.range(at: 2)
        let language = langRange.location != NSNotFound ? String(content[Range(langRange, in: content)!]) : nil
        let code = String(content[Range(codeRange, in: content)!])
        segments.append(.code(language: language?.isEmpty == false ? language : nil, code: code))
        lastEnd = matchRange.upperBound
    }

    if lastEnd < content.endIndex {
        let textSegment = String(content[lastEnd..<content.endIndex])
        segments.append(contentsOf: parseImagesAndArtifacts(textSegment))
    }

    if segments.isEmpty {
        segments.append(.text(content))
    }

    return segments
}

func parseImagesAndArtifacts(_ text: String) -> [MessageSegment] {
    var result: [MessageSegment] = []

    // Parse images
    let imagePattern = "!\\[([^\\]]*)\\]\\((data:image/[^;]+;base64,([A-Za-z0-9+/=]+))\\)"
    guard let imageRegex = try? NSRegularExpression(pattern: imagePattern, options: []) else {
        if !text.isEmpty { result.append(.text(text)) }
        return result
    }

    // Parse artifacts
    let artifactPattern = "<artifact type=\"(\\w+)\"\\>([\\s\\S]*?)<\\/artifact>"
    guard let artifactRegex = try? NSRegularExpression(pattern: artifactPattern, options: []) else {
        if !text.isEmpty { result.append(.text(text)) }
        return result
    }

    let nsRange = NSRange(text.startIndex..., in: text)
    let imageMatches = imageRegex.matches(in: text, options: [], range: nsRange)
    let artifactMatches = artifactRegex.matches(in: text, options: [], range: nsRange)

    // Combine and sort matches
    var allMatches: [(range: Range<String.Index>, type: String, data: String)] = []

    for match in imageMatches {
        if let range = Range(match.range, in: text) {
            let base64Range = match.range(at: 3)
            let base64 = String(text[Range(base64Range, in: text)!])
            allMatches.append((range, "image", base64))
        }
    }

    for match in artifactMatches {
        if let range = Range(match.range, in: text) {
            let typeRange = match.range(at: 1)
            let dataRange = match.range(at: 2)
            let type = String(text[Range(typeRange, in: text)!])
            let data = String(text[Range(dataRange, in: text)!])
            allMatches.append((range, "artifact:\(type)", data))
        }
    }

    allMatches.sort { $0.range.lowerBound < $1.range.lowerBound }

    var lastEnd = text.startIndex
    for match in allMatches {
        if lastEnd < match.range.lowerBound {
            let t = String(text[lastEnd..<match.range.lowerBound])
            if !t.isEmpty { result.append(.text(t)) }
        }
        if match.type.hasPrefix("artifact:") {
            let artifactType = String(match.type.dropFirst(9))
            result.append(.artifact(type: artifactType, data: match.data))
        } else {
            result.append(.image(base64: match.data))
        }
        lastEnd = match.range.upperBound
    }

    if lastEnd < text.endIndex {
        let t = String(text[lastEnd..<text.endIndex])
        if !t.isEmpty { result.append(.text(t)) }
    }

    if result.isEmpty && !text.isEmpty {
        result.append(.text(text))
    }

    return result
}

// MARK: - Tab Enum

enum Tab {
    case chats, agents, memory, settings
}
