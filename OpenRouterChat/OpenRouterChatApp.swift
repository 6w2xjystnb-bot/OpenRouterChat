import SwiftUI
import SwiftData

@main
struct OpenRouterChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Chat.self, Message.self, ChatMemory.self, MCPServer.self])
    }
}
