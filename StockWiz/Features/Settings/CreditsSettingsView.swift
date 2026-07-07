import SwiftUI

struct CreditsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var credits: CreditsStatus?
    @State private var loading = true
    @State private var keyInput = ""
    @State private var saving = false
    @State private var removing = false
    @State private var keyError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("AI Credits", systemImage: "sparkles")
                    Text("Every account gets a free monthly allowance of Claude AI usage for stock analysis, chat, predictions, and natural-language search. Add your own Anthropic API key for unlimited, unmetered usage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if loading {
                    Section { ProgressView() }
                } else if let credits {
                    if credits.hasOwnKey {
                        ownKeySection
                    } else {
                        usageSection(credits)
                        addKeySection
                    }
                }
            }
            .navigationTitle("AI Credits")
            .toolbar { Button("Done") { dismiss() } }
            .task { await load() }
        }
    }

    // MARK: Own key state

    private var ownKeySection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(DS.Color.accent.opacity(0.12))
                    Image(systemName: "key.fill").font(.system(size: 13)).foregroundStyle(DS.Color.accent)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Using your own API key").font(.subheadline)
                    Text("Unmetered — billed directly to your Anthropic account").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Button(removing ? "Removing…" : "Remove key", role: .destructive) {
                Task { await removeKey() }
            }
            .disabled(removing)
        }
    }

    // MARK: Usage state

    private func usageSection(_ credits: CreditsStatus) -> some View {
        Section("This month") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(credits.tokensUsed.formatted()) / \(credits.tokenLimit.formatted()) tokens")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    DSBadge(
                        credits.exhausted ? "Exhausted" : credits.warning ? "Low" : "Active",
                        color: credits.exhausted ? DS.Color.rose : credits.warning ? DS.Color.amber : DS.Color.accent
                    )
                }
                ProgressView(value: min(credits.pctUsed, 1.0))
                    .tint(credits.exhausted ? DS.Color.rose : credits.warning ? DS.Color.amber : DS.Color.accent)

                if credits.exhausted {
                    Text("You're out of free credits — AI features are paused until next month or you add your own key below.")
                        .font(.caption).foregroundStyle(DS.Color.rose)
                } else if credits.warning {
                    Text("You're close to your monthly limit.")
                        .font(.caption).foregroundStyle(DS.Color.amber)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var addKeySection: some View {
        Section("Add your own Anthropic API key") {
            Text("Get one at console.anthropic.com. Your key is stored securely and never shown again after saving.")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("sk-ant-...", text: $keyInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if let keyError {
                Text(keyError).font(.caption).foregroundStyle(DS.Color.rose)
            }
            Button(saving ? "Validating…" : "Save key") {
                Task { await saveKey() }
            }
            .foregroundStyle(DS.Color.accent)
            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
    }

    // MARK: Actions

    private func load() async {
        loading = true
        credits = try? await APIClient.shared.credits()
        loading = false
    }

    private func saveKey() async {
        saving = true; keyError = nil
        defer { saving = false }
        do {
            credits = try await APIClient.shared.setAPIKey(keyInput.trimmingCharacters(in: .whitespaces))
            keyInput = ""
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func removeKey() async {
        removing = true
        defer { removing = false }
        credits = try? await APIClient.shared.removeAPIKey()
    }
}
