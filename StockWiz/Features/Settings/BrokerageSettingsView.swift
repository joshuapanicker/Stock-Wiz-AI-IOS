import SwiftUI
import WebKit

struct BrokerageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status: BrokerageStatus?
    @State private var loading = true
    @State private var linkToken: String?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section { Label("Brokerage Sync", systemImage: "building.columns.fill"); Text("Connect and manage investment accounts through Plaid.").font(.caption).foregroundStyle(.secondary) }
                if loading { ProgressView() }
                ForEach(status?.connections ?? []) { connection in
                    HStack { VStack(alignment: .leading) { Text(connection.institution.isEmpty ? "Brokerage Account" : connection.institution); Text("Connected").font(.caption).foregroundStyle(.green) }; Spacer(); Button("Disconnect", role: .destructive) { Task { try? await APIClient.shared.disconnectBrokerage(id: connection.id, removeHoldings: false); await load() } } }
                }
                Section {
                    Button { Task { await connect() } } label: { Label(loading ? "Preparing…" : "Connect another brokerage", systemImage: "plus.circle") }.disabled(loading)
                    Text("Your credentials are entered directly in Plaid's secure connection window. StockWiz receives read-only investment holdings.").font(.caption).foregroundStyle(.secondary)
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Brokerage").toolbar { Button("Done") { dismiss() } }.task { await load() }
            .fullScreenCover(isPresented: Binding(get: { linkToken != nil }, set: { if !$0 { linkToken = nil } })) {
                if let linkToken { PlaidConnectSheet(linkToken: linkToken, onSuccess: { token, institution in Task { await exchange(token, institution: institution) } }, onExit: { message in linkTokenDismiss(message) }) }
            }
        }
    }
    private func load() async { loading = true; status = try? await APIClient.shared.brokerageStatus(); loading = false }
    private func connect() async { loading = true; error = nil; do { linkToken = try await APIClient.shared.plaidLinkToken() } catch { self.error = error.localizedDescription }; loading = false }
    private func exchange(_ token: String, institution: String) async { do { _ = try await APIClient.shared.exchangePlaidToken(token, institution: institution); linkToken = nil; await load() } catch { self.error = error.localizedDescription; linkToken = nil } }
    private func linkTokenDismiss(_ message: String?) { linkToken = nil; if let message, !message.isEmpty { error = message } }
}

private struct PlaidConnectSheet: View {
    let linkToken: String; let onSuccess: (String, String) -> Void; let onExit: (String?) -> Void
    @State private var loaded = false
    var body: some View {
        NavigationStack {
            ZStack {
                PlaidLinkView(linkToken: linkToken, onReady: { loaded = true }, onSuccess: onSuccess, onExit: onExit)
                if !loaded { VStack(spacing: 12) { ProgressView(); Text("Opening secure Plaid Link…").font(.caption).foregroundStyle(.secondary) }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            }
            .navigationTitle("Connect Brokerage").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onExit(nil) } } }
        }
    }
}

@MainActor private struct PlaidLinkView: UIViewRepresentable {
    let linkToken: String
    let onReady: () -> Void
    let onSuccess: (String, String) -> Void
    let onExit: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onReady: onReady, onSuccess: onSuccess, onExit: onExit) }
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController(); controller.add(context.coordinator, name: "plaid")
        let configuration = WKWebViewConfiguration(); configuration.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false; webView.backgroundColor = .clear
        let encoded = (try? JSONEncoder().encode(linkToken)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
        <body style="margin:0;background:#090b0d"><script>
        function post(value){ window.webkit.messageHandlers.plaid.postMessage(value); }
        function launch(){ post({type:'ready'}); const handler = Plaid.create({token: \(encoded), onSuccess: (token, metadata) => post({type:'success', token:token, institution:metadata.institution?.name || ''}), onExit: (err) => post({type:'exit', message:err?.display_message || err?.error_message || ''})}); handler.open(); }
        function failed(){ post({type:'exit', message:'Plaid Link could not load. Check your connection and try again.'}); }
        const script = document.createElement('script'); script.src = 'https://cdn.plaid.com/link/v2/stable/link-initialize.js'; script.onload = launch; script.onerror = failed; document.head.appendChild(script);
        </script></body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://cdn.plaid.com")); return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onReady: () -> Void; let onSuccess: (String, String) -> Void; let onExit: (String?) -> Void
        init(onReady: @escaping () -> Void, onSuccess: @escaping (String, String) -> Void, onExit: @escaping (String?) -> Void) { self.onReady = onReady; self.onSuccess = onSuccess; self.onExit = onExit }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            if type == "ready" { onReady() }
            else if type == "success", let token = body["token"] as? String { onSuccess(token, body["institution"] as? String ?? "") }
            else { onExit(body["message"] as? String) }
        }
    }
}
