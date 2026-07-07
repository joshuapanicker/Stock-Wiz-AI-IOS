import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DSAuroraBackground(intensity: 0.7)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // MARK: User card
                        userCard

                        // MARK: Settings section
                        sectionCard(title: "SETTINGS") {
                            navRow("Investment Profile",      icon: "person.text.rectangle.fill", tint: DS.Color.sky,    destination: AnyView(InvestmentProfileView()))
                            Divider().background(DS.Color.border)
                            navRow("Buy, Watch & Sell Rules", icon: "checklist",                  tint: DS.Color.accent, destination: AnyView(CriteriaSettingsView()))
                            Divider().background(DS.Color.border)
                            navRow("Price Alerts",            icon: "bell.fill",                  tint: DS.Color.amber,  destination: AnyView(AlertsSettingsView()))
                            Divider().background(DS.Color.border)
                            navRow("Brokerage Accounts",      icon: "building.columns.fill",       tint: DS.Color.violet, destination: AnyView(BrokerageSettingsView()))
                        }

                        // MARK: Security section
                        sectionCard(title: "SECURITY") {
                            infoRow("Authentication", value: "Supabase", icon: "lock.shield.fill", tint: DS.Color.gain)
                            Divider().background(DS.Color.border)
                            Button(role: .destructive) {
                                Task { await authStore.signOut() }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(DS.Color.loss.opacity(0.12))
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 13))
                                            .foregroundStyle(DS.Color.loss)
                                    }
                                    .frame(width: 32, height: 32)
                                    Text("Sign Out")
                                        .font(.subheadline)
                                        .foregroundStyle(DS.Color.loss)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }

                        // MARK: Version footer
                        Text("StockWiz for iOS")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: User card
    /// Monogram derived from the account email, e.g. "joshua@…" → "J"
    private var monogram: String {
        let email = authStore.session?.user.email ?? "S"
        return String(email.prefix(1)).uppercased()
    }

    private var userCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Gradient-ring monogram avatar
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(colors: [DS.Color.accent, DS.Color.violet, DS.Color.sky, DS.Color.accent], center: .center),
                            lineWidth: 2.5
                        )
                    Circle()
                        .fill(DS.Color.surfaceHigh)
                        .padding(5)
                    Text(monogram)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Color.accent)
                }
                .frame(width: 62, height: 62)
                .shadow(color: DS.Color.accent.opacity(0.25), radius: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("StockWiz Investor")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(authStore.session?.user.email ?? "Signed in")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                DSBadge("PRO", color: DS.Color.accent, solid: true)
            }

            Divider().background(DS.Color.border)

            HStack {
                Label("AI-powered market intelligence", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
                DSLiveDot()
            }
        }
        .dsHeroCard()
    }

    // MARK: Section card builder
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DSSectionHeader(title: title)
            VStack(spacing: 0) {
                content()
            }
        }
        .dsCard()
    }

    // MARK: Nav row
    private func navRow<Destination: View>(_ title: String, icon: String, tint: Color, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(tint.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Info row
    private func infoRow(_ label: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(tint.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Investment Profile View
private struct InvestmentProfileView: View {
    @State private var profile = InvestmentProfile.defaults
    @State private var loading = true
    @State private var error: String?
    @State private var saved = false
    let sectors = ["Technology", "Healthcare", "Financial Services", "Consumer Cyclical",
                   "Industrials", "Energy", "Real Estate", "Communication Services"]

    var body: some View {
        Form {
            if loading {
                ProgressView("Loading your profile…")
            } else {
                Picker("Risk tolerance", selection: binding(\.riskTolerance)) {
                    Text("Conservative").tag("conservative")
                    Text("Moderate").tag("moderate")
                    Text("Aggressive").tag("aggressive")
                }
                Picker("Hold duration", selection: binding(\.holdDuration)) {
                    Text("Short").tag("short")
                    Text("Medium").tag("medium")
                    Text("Long").tag("long")
                }
                TextField("Maximum position ($)", value: binding(\.maxPositionUSD), format: .number).keyboardType(.decimalPad)
                Toggle("Tax sensitive", isOn: binding(\.taxSensitive))
                Section("Preferred sectors") {
                    ForEach(sectors, id: \.self) { sector in
                        Toggle(sector, isOn: Binding(
                            get: { profile.preferredSectors.contains(sector) },
                            set: { on in
                                if on { profile.preferredSectors.append(sector) }
                                else  { profile.preferredSectors.removeAll { $0 == sector } }
                            }
                        ))
                    }
                }
                Section("Notes") {
                    TextField("Investment goals and preferences", text: binding(\.notes), axis: .vertical)
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Try Again") { Task { await load() } }
                }
                Button(saved ? "Saved ✓" : "Save Profile") {
                    Task {
                        do {
                            profile = try await APIClient.shared.saveProfile(profile)
                            saved = true; error = nil
                        } catch { self.error = error.localizedDescription }
                    }
                }
                .foregroundStyle(DS.Color.accent)
                .disabled(profile.riskTolerance.isEmpty)
            }
        }
        .navigationTitle("Investment Profile")
        .task { await load() }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<InvestmentProfile, T>) -> Binding<T> {
        Binding(get: { profile[keyPath: keyPath] }, set: { profile[keyPath: keyPath] = $0; saved = false })
    }

    private func load() async {
        loading = true; error = nil
        do { profile = try await APIClient.shared.profile() } catch { self.error = error.localizedDescription }
        loading = false
    }
}

// MARK: - Alerts Settings View
private struct AlertsSettingsView: View {
    @State private var alerts: [UserAlert] = []
    @State private var symbol = ""
    @State private var threshold = ""
    @State private var type = "price_above"

    var body: some View {
        List {
            Section("New Alert") {
                TextField("Symbol", text: $symbol).textInputAutocapitalization(.characters)
                Picker("Condition", selection: $type) {
                    Text("Price rises above").tag("price_above")
                    Text("Price falls below").tag("price_below")
                    Text("Meets buy criteria").tag("meets_buy_criteria")
                    Text("Meets watch criteria").tag("meets_watch_criteria")
                }
                if type.hasPrefix("price") {
                    TextField("Price", text: $threshold).keyboardType(.decimalPad)
                }
                Button("Create Alert") {
                    Task {
                        if let a = try? await APIClient.shared.createAlert(symbol: symbol, type: type, threshold: Double(threshold)) {
                            alerts.insert(a, at: 0); symbol = ""
                        }
                    }
                }
                .foregroundStyle(DS.Color.accent)
                .disabled(symbol.isEmpty)
            }
            Section("Alerts") {
                ForEach($alerts) { $alert in
                    Toggle(isOn: Binding(
                        get: { alert.enabled },
                        set: { enabled in
                            alert.enabled = enabled
                            Task { _ = try? await APIClient.shared.toggleAlert(id: alert.id, enabled: enabled) }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(alert.symbol).font(.body.monospaced())
                            Text(alert.alertType.replacingOccurrences(of: "_", with: " "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { alerts[$0].id }
                    alerts.remove(atOffsets: offsets)
                    Task { for id in ids { try? await APIClient.shared.deleteAlert(id: id) } }
                }
            }
        }
        .navigationTitle("Price Alerts")
        .task { alerts = (try? await APIClient.shared.alerts()) ?? [] }
    }
}

// MARK: - Criteria Settings View
private struct CriteriaSettingsView: View {
    @State private var configuration: CriteriaConfiguration?
    @State private var selected = "buy"
    @State private var saving = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Strategy Presets") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(CriteriaPreset.all) { preset in
                            Button {
                                configuration = preset.configuration
                                message = "\(preset.name) preset loaded — tap Save to apply"
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Label(preset.name, systemImage: preset.icon).font(.headline)
                                    Text(preset.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                }
                                .frame(width: 155, alignment: .leading)
                                .padding(12)
                                .background(DS.Color.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.accent.opacity(0.2)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Picker("Signal", selection: $selected) {
                Text("Buy").tag("buy"); Text("Watch").tag("watch"); Text("Sell").tag("sell")
            }.pickerStyle(.segmented)

            if configuration != nil {
                Section("Rules required") {
                    Stepper("\(mode.wrappedValue.minRulesMet) of \(mode.wrappedValue.rules.count)",
                            value: minRules, in: 1...max(1, mode.wrappedValue.rules.count))
                }
                Section("Rules") {
                    ForEach(mode.wrappedValue.rules.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Description", text: rule(index).description).font(.headline)
                            Picker("Operator", selection: rule(index).operator) {
                                ForEach(operators(for: mode.wrappedValue.rules[index]), id: \.self) {
                                    Text(operatorLabel($0)).tag($0)
                                }
                            }
                            TextField("Threshold", text: ruleValue(index))
                                .keyboardType(isNumeric(index) ? .numbersAndPunctuation : .default)
                            Text(mode.wrappedValue.rules[index].field
                                    .replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        mode.wrappedValue.rules.remove(atOffsets: offsets)
                        mode.wrappedValue.minRulesMet = min(mode.wrappedValue.minRulesMet, max(1, mode.wrappedValue.rules.count))
                    }
                }
                Section {
                    Button(saving ? "Saving…" : "Save Criteria") { Task { await save() } }
                        .foregroundStyle(DS.Color.accent)
                        .disabled(saving)
                    if let message {
                        Text(message).font(.caption)
                            .foregroundStyle(message == "Saved" ? DS.Color.gain : DS.Color.loss)
                    }
                }
            } else {
                ProgressView("Loading your strategy…")
            }
        }
        .navigationTitle("Buy, Watch & Sell")
        .task { configuration = try? await APIClient.shared.criteria() }
    }

    private var mode: Binding<CriteriaMode> {
        Binding(
            get: { selected == "buy" ? configuration!.buy : selected == "watch" ? configuration!.watch : configuration!.sell },
            set: { if selected == "buy" { configuration!.buy = $0 } else if selected == "watch" { configuration!.watch = $0 } else { configuration!.sell = $0 } }
        )
    }
    private var minRules: Binding<Int> {
        Binding(get: { mode.wrappedValue.minRulesMet }, set: { mode.wrappedValue.minRulesMet = $0 })
    }
    private func rule(_ index: Int) -> Binding<CriteriaSettingRule> {
        Binding(get: { mode.wrappedValue.rules[index] }, set: { mode.wrappedValue.rules[index] = $0 })
    }
    private func ruleValue(_ index: Int) -> Binding<String> {
        Binding(get: { mode.wrappedValue.rules[index].value.display }, set: { mode.wrappedValue.rules[index].value.display = $0 })
    }
    private func isNumeric(_ index: Int) -> Bool {
        if case .number = mode.wrappedValue.rules[index].value { true } else { false }
    }
    private func operators(for rule: CriteriaSettingRule) -> [String] {
        if case .number = rule.value { ["lt", "lte", "gt", "gte"] } else { ["eq", "neq"] }
    }
    private func operatorLabel(_ value: String) -> String {
        ["lt": "Less than", "lte": "At most", "gt": "Greater than",
         "gte": "At least", "eq": "Equals", "neq": "Does not equal"][value] ?? value
    }
    private func save() async {
        guard let configuration else { return }
        saving = true; defer { saving = false }
        do { try await APIClient.shared.saveCriteria(configuration); message = "Saved" }
        catch { message = error.localizedDescription }
    }
}

// MARK: - Criteria Presets
private struct CriteriaPreset: Identifiable {
    let id: String; let name: String; let summary: String; let icon: String
    let configuration: CriteriaConfiguration

    static let all: [CriteriaPreset] = [
        .init(id: "value", name: "Value Investor", summary: "Reasonable P/E, margins, near yearly lows", icon: "dollarsign.circle",
              configuration: config(buy: (4, [("near_low","Within 20% of 52-week low","distance_to_low_pct","lt",.number(0.20)),("low_pe","Forward P/E below 20","forward_pe","lt",.number(20)),("profit","Positive profit margin","profit_margin","gt",.number(0)),("revenue","Positive revenue growth","revenue_growth","gt",.number(0)),("market","Market not bearish","market_trend","neq",.text("bearish"))]),
                              watch: (3, [("moderate_low","Within 40% of 52-week low","distance_to_low_pct","lt",.number(0.40)),("acceptable_pe","Forward P/E below 30","forward_pe","lt",.number(30)),("op_margin","Positive operating margin","operating_margin","gt",.number(0)),("earnings","Positive earnings growth","earnings_growth","gt",.number(0))]),
                              sell:  (2, [("near_high","Within 10% of 52-week high","distance_to_high_pct","lt",.number(0.10)),("overvalued","Trailing P/E over 40","trailing_pe","gt",.number(40)),("neg_revenue","Revenue growth negative","revenue_growth","lt",.number(0)),("profit_target","Gained more than 30%","gain_pct","gt",.number(0.30))]))),
        .init(id: "growth", name: "Growth Hunter", summary: "Strong revenue and earnings momentum", icon: "chart.line.uptrend.xyaxis",
              configuration: config(buy: (3, [("high_revenue","Revenue growth above 15%","revenue_growth","gt",.number(0.15)),("high_earnings","Earnings growth above 10%","earnings_growth","gt",.number(0.10)),("pe_cap","Forward P/E below 50","forward_pe","lt",.number(50)),("profitable","Positive profit margin","profit_margin","gt",.number(0))]),
                              watch: (2, [("decent_revenue","Revenue growth above 8%","revenue_growth","gt",.number(0.08)),("decent_earnings","Earnings growth above 5%","earnings_growth","gt",.number(0.05)),("pe_watch","Forward P/E below 70","forward_pe","lt",.number(70))]),
                              sell:  (2, [("neg_revenue","Revenue growth turned negative","revenue_growth","lt",.number(0)),("big_gain","Gained more than 50%","gain_pct","gt",.number(0.50)),("bearish","Market is bearish","market_trend","eq",.text("bearish"))]))),
        .init(id: "momentum", name: "Momentum Trader", summary: "Price strength and positive market conditions", icon: "bolt.fill",
              configuration: config(buy: (3, [("near_high","Within 15% of 52-week high","distance_to_high_pct","lt",.number(0.15)),("bullish","Market is bullish","market_trend","eq",.text("bullish")),("revenue","Positive revenue growth","revenue_growth","gt",.number(0)),("margin","Positive profit margin","profit_margin","gt",.number(0))]),
                              watch: (2, [("not_far_high","Within 30% of 52-week high","distance_to_high_pct","lt",.number(0.30)),("not_bearish","Market not bearish","market_trend","neq",.text("bearish")),("earnings","Positive earnings growth","earnings_growth","gt",.number(0))]),
                              sell:  (1, [("bearish","Market turns bearish","market_trend","eq",.text("bearish")),("far_from_high","More than 20% from 52-week high","distance_to_high_pct","gt",.number(0.20)),("profit_target","Gained more than 25%","gain_pct","gt",.number(0.25))]))),
        .init(id: "conservative", name: "Conservative", summary: "Profitability-first, lower risk thresholds", icon: "shield.checkered",
              configuration: config(buy: (5, [("near_low","Within 25% of 52-week low","distance_to_low_pct","lt",.number(0.25)),("low_pe","Forward P/E below 25","forward_pe","lt",.number(25)),("strong_margin","Profit margin above 10%","profit_margin","gt",.number(0.10)),("revenue","Positive revenue growth","revenue_growth","gt",.number(0)),("market","Market is bullish","market_trend","eq",.text("bullish"))]),
                              watch: (3, [("moderate_low","Within 35% of 52-week low","distance_to_low_pct","lt",.number(0.35)),("pe","Forward P/E below 35","forward_pe","lt",.number(35)),("margin","Profit margin above 5%","profit_margin","gt",.number(0.05)),("not_bearish","Market not bearish","market_trend","neq",.text("bearish"))]),
                              sell:  (1, [("neg_revenue","Revenue growth negative","revenue_growth","lt",.number(0)),("bearish","Market is bearish","market_trend","eq",.text("bearish")),("profit_target","Gained more than 20%","gain_pct","gt",.number(0.20))])))
    ]

    private typealias RawRule = (String, String, String, String, CriterionValue)
    private static func config(buy: (Int, [RawRule]), watch: (Int, [RawRule]), sell: (Int, [RawRule])) -> CriteriaConfiguration {
        func mode(_ title: String, _ input: (Int, [RawRule])) -> CriteriaMode {
            CriteriaMode(description: title, rules: input.1.map { CriteriaSettingRule(id: $0.0, description: $0.1, field: $0.2, operator: $0.3, value: $0.4) }, minRulesMet: input.0)
        }
        return CriteriaConfiguration(buy: mode("Buy criteria", buy), watch: mode("Watch criteria", watch), sell: mode("Sell criteria", sell))
    }
}
