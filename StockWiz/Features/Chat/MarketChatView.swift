import Observation
import SwiftUI

private struct SavedChat: Codable, Identifiable { let id: UUID; var title: String; var messages: [ChatMessage]; let createdAt: Date }

@MainActor @Observable
private final class MarketChatModel {
    var sessions: [SavedChat] = []; var activeID: UUID?; var input = ""; var streaming = false; var error: String?
    var messages: [ChatMessage] { get { sessions.first(where: { $0.id == activeID })?.messages ?? [] } set { if let i = sessions.firstIndex(where: { $0.id == activeID }) { sessions[i].messages = newValue; save() } } }
    init() { if let data = UserDefaults.standard.data(forKey: "marketChatSessions"), let saved = try? JSONDecoder().decode([SavedChat].self, from: data) { sessions = saved }; selectOrCreate() }
    func selectOrCreate() { if let first = sessions.first { activeID = first.id } else { newChat() } }
    func newChat() { let chat = SavedChat(id: UUID(), title: "New market chat", messages: [], createdAt: Date()); sessions.insert(chat, at: 0); activeID = chat.id; save() }
    func select(_ id: UUID) { activeID = id }
    func delete(_ id: UUID) { sessions.removeAll { $0.id == id }; selectOrCreate(); save() }
    func send(_ suggestion: String? = nil) async {
        let text = (suggestion ?? input).trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty, !streaming else { return }
        input = ""; error = nil; var current = messages; current.append(.init(role: "user", content: text)); let outgoing = current, assistantID = UUID(); current.append(.init(id: assistantID, role: "assistant", content: "")); messages = current; streaming = true
        defer { streaming = false; save() }
        do { for try await payload in try await APIClient.shared.streamGeneralChat(messages: outgoing) { guard let data = payload.data(using: .utf8), let token = try? JSONDecoder().decode(StreamToken.self, from: data) else { continue }; var updated = messages; if let i = updated.firstIndex(where: { $0.id == assistantID }) { updated[i].content += token.token; messages = updated } } } catch { self.error = error.localizedDescription }
        if let i = sessions.firstIndex(where: { $0.id == activeID }), sessions[i].title == "New market chat" { sessions[i].title = String(text.prefix(34)) }
    }
    private func save() { if let data = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(data, forKey: "marketChatSessions") } }
}

struct MarketChatView: View {
    @State private var model = MarketChatModel(); @State private var showingHistory = false
    private let prompts = [("chart.line.uptrend.xyaxis", "Market pulse", "What sectors look strong right now?"), ("scale.3d", "Compare styles", "Explain growth vs value investing"), ("waveform.path.ecg", "Read volatility", "How should I interpret the VIX?"), ("function", "Value a company", "How do I evaluate valuation?")]
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                assistantBackground

                // Messages scroll — bottom padding clears the composer + floating tab bar
                ScrollView { LazyVStack(spacing: 16) {
                    if model.messages.isEmpty { welcome }
                    ForEach(model.messages) { messageRow($0) }
                    if model.streaming { thinkingIndicator }
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red).font(.caption).padding()
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(.horizontal, 16).padding(.bottom, 180) }

                // Composer floats above the floating tab bar
                composer
                    .padding(.horizontal, 12)
                    .padding(.bottom, 90) // clears the floating tab bar
            }
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingHistory = true } label: { Image(systemName: "clock.arrow.circlepath").padding(7).background(DS.Color.surface, in: Circle()).overlay(Circle().stroke(DS.Color.border)) }
                Button { model.newChat() } label: { Image(systemName: "square.and.pencil").padding(7).background(DS.Color.accent.opacity(0.1), in: Circle()).foregroundStyle(DS.Color.accent) }
            }}
            .sheet(isPresented: $showingHistory) { historySheet }
        }
    }

    private var assistantBackground: some View {
        ZStack(alignment: .top) {
            DS.Color.background.ignoresSafeArea()
            DS.Gradient.ambientGreen(opacity: 0.14).frame(height: 540).ignoresSafeArea()
            DS.Gradient.ambientViolet(opacity: 0.07).frame(height: 700).ignoresSafeArea()
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle().fill(DS.Color.accent.opacity(0.13))
                        Circle().stroke(DS.Color.accent.opacity(0.3))
                        Image(systemName: "sparkles").font(.title2).foregroundStyle(DS.Color.accent)
                    }.frame(width: 58, height: 58)
                    Spacer()
                    DSLiveDot()
                }
                Text("Market Assistant").font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-0.8).foregroundStyle(DS.Color.textPrimary)
                Text("Move from question to investment insight with a context-aware assistant built for market research.").font(.subheadline).foregroundStyle(DS.Color.textSecondary).lineSpacing(4)
                HStack(spacing: 14) {
                    capability("chart.xyaxis.line", "Live context")
                    capability("doc.text.magnifyingglass", "Deep research")
                    capability("lock.shield", "Private")
                }
            }
            .padding(20)
            .background(DS.Gradient.heroCard, in: RoundedRectangle(cornerRadius: DS.Radius.xlarge))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xlarge).stroke(LinearGradient(colors: [DS.Color.accent.opacity(0.32), DS.Color.border], startPoint: .topLeading, endPoint: .bottomTrailing)))

            HStack {
                Text("START A RESEARCH THREAD").font(.caption2.bold()).tracking(1.2).foregroundStyle(DS.Color.textSecondary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(prompts, id: \.2) { icon, title, prompt in
                    Button { Task { await model.send(prompt) } } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Image(systemName: icon).foregroundStyle(DS.Color.accent)
                            Text(title).font(.subheadline.bold()).foregroundStyle(DS.Color.textPrimary)
                            Text(prompt).font(.caption2).foregroundStyle(DS.Color.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                        .padding(14)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.large))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.border))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.top, 10)
    }

    private func capability(_ icon: String, _ title: String) -> some View { Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary) }

    private func messageRow(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 9) {
            if msg.role == "user" { Spacer(minLength: 38) }
            if msg.role != "user" {
                ZStack {
                    Circle().fill(DS.Color.accent.opacity(0.12))
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(DS.Color.accent)
                }.frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(msg.role == "user" ? "YOU" : "STOCKWIZ INTELLIGENCE")
                    .font(.system(size: 9, weight: .bold)).tracking(1)
                    .foregroundStyle(msg.role == "user" ? DS.Color.textSecondary : DS.Color.accent)
                Text(msg.content.isEmpty ? "Analyzing…" : msg.content)
                    .font(.subheadline).lineSpacing(4).textSelection(.enabled)
                    .foregroundStyle(DS.Color.textPrimary)
            }
            .padding(14)
            .background(
                msg.role == "user" ? DS.Color.surface : DS.Color.accent.opacity(0.055),
                in: RoundedRectangle(cornerRadius: DS.Radius.large)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .stroke(msg.role == "user" ? DS.Color.border : DS.Color.accent.opacity(0.13))
            )
            if msg.role != "user" { Spacer(minLength: 20) }
        }
    }

    private var thinkingIndicator: some View { HStack(spacing: 7) { ProgressView().controlSize(.small).tint(DS.Color.accent); Text("Reading the market…").font(.caption).foregroundStyle(DS.Color.textSecondary); Spacer() }.padding(.leading, 40) }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(DS.Color.accent).padding(.bottom, 8)
            TextField("Ask about a stock, sector, or strategy…", text: Binding(get: { model.input }, set: { model.input = $0 }), axis: .vertical)
                .lineLimit(1...5).padding(.vertical, 8)
            Button { Task { await model.send() } } label: {
                Image(systemName: "arrow.up").font(.headline.bold()).frame(width: 38, height: 38)
                    .background(model.input.isEmpty ? DS.Color.surface : DS.Color.accent, in: Circle())
                    .foregroundStyle(model.input.isEmpty ? DS.Color.textTertiary : DS.Color.background)
            }.disabled(model.input.isEmpty || model.streaming)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xlarge))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xlarge).stroke(DS.Color.border))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    private var historySheet: some View { NavigationStack { List { if model.sessions.isEmpty { ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right") }; ForEach(model.sessions) { chat in Button { model.select(chat.id); showingHistory = false } label: { HStack { Image(systemName: "bubble.left.fill").foregroundStyle(.green); VStack(alignment: .leading, spacing: 4) { Text(chat.title).foregroundStyle(.primary); Text(chat.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) } }.buttonStyle(.plain) }.onDelete { offsets in offsets.map { model.sessions[$0].id }.forEach(model.delete) } }.navigationTitle("Research History").toolbar { Button("Done") { showingHistory = false } } } }
}
