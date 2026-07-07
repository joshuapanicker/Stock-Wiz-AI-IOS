import Observation
import SwiftUI

@MainActor
@Observable
private final class StockChatModel {
    let symbol: String
    var messages: [ChatMessage] = []
    var input = ""
    var isStreaming = false
    var errorMessage: String?

    init(symbol: String) { self.symbol = symbol }

    func send(_ suggestedText: String? = nil) async {
        let text = (suggestedText ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        input = ""
        errorMessage = nil
        messages.append(ChatMessage(role: "user", content: text))
        let requestMessages = messages
        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: "assistant", content: ""))
        isStreaming = true
        defer { isStreaming = false }

        do {
            let stream = try await APIClient.shared.streamStockChat(symbol: symbol, messages: requestMessages)
            for try await payload in stream {
                guard let data = payload.data(using: .utf8),
                      let token = try? JSONDecoder().decode(StreamToken.self, from: data),
                      let index = messages.firstIndex(where: { $0.id == assistantID }) else { continue }
                messages[index].content += token.token
            }
        } catch {
            errorMessage = error.localizedDescription
            if let index = messages.firstIndex(where: { $0.id == assistantID }), messages[index].content.isEmpty {
                messages.remove(at: index)
            }
        }
    }
}

struct StockChatView: View {
    @State private var model: StockChatModel

    private let suggestions = [
        "Why is this stock worth watching?",
        "What are the biggest risks right now?",
        "Is this a good entry point?",
        "Explain the valuation and growth"
    ]

    init(symbol: String) { _model = State(initialValue: StockChatModel(symbol: symbol)) }

    var body: some View {
        VStack(spacing: 12) {
            conversation

            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
            composer
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var conversation: some View {
        if model.messages.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Label("Ask anything about \(model.symbol)", systemImage: "bubble.left.and.sparkles")
                    .font(.headline).foregroundStyle(.green)
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { Task { await model.send(suggestion) } }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(model.messages) { message in messageRow(message) }
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isUser = message.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 45) }
            VStack(alignment: .leading, spacing: 4) {
                Text(isUser ? "YOU" : "STOCKWIZ AI")
                    .font(.caption2.bold())
                    .foregroundStyle(isUser ? DS.Color.textSecondary : DS.Color.accent)
                if message.content.isEmpty {
                    ProgressView().tint(DS.Color.accent)
                } else {
                    Text(message.content).lineSpacing(3).textSelection(.enabled)
                        .foregroundStyle(DS.Color.textPrimary)
                }
            }
            .padding(12)
            .background(
                isUser ? DS.Color.accent.opacity(0.10) : DS.Color.surface,
                in: RoundedRectangle(cornerRadius: DS.Radius.medium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .stroke(isUser ? DS.Color.accent.opacity(0.2) : DS.Color.border)
            )
            if !isUser { Spacer(minLength: 25) }
        }
    }

    private var composer: some View {
        HStack {
            TextField(
                "Ask about \(model.symbol)…",
                text: Binding(get: { model.input }, set: { model.input = $0 }),
                axis: .vertical
            )
            .lineLimit(1...4)
            .foregroundStyle(DS.Color.textPrimary)
            .onSubmit { Task { await model.send() } }
            Button { Task { await model.send() } } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        model.input.trimmingCharacters(in: .whitespaces).isEmpty
                            ? DS.Color.textTertiary
                            : DS.Color.accent
                    )
            }
            .disabled(model.input.trimmingCharacters(in: .whitespaces).isEmpty || model.isStreaming)
        }
        .padding(11)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
    }
}
