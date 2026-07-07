import SwiftUI

// MARK: - Design System
// Central design tokens for StockWiz iOS.

enum DS {

    // MARK: Colors
    enum Color {
        /// True near-black background
        static let background   = SwiftUI.Color(red: 0.047, green: 0.051, blue: 0.059)
        /// Elevated surface for cards
        static let surface      = SwiftUI.Color(red: 0.082, green: 0.086, blue: 0.102)
        /// Higher-elevation card / modal
        static let surfaceHigh  = SwiftUI.Color(red: 0.114, green: 0.118, blue: 0.145)
        /// Stroke / divider
        static let border       = SwiftUI.Color.white.opacity(0.08)
        /// Stronger border
        static let borderStrong = SwiftUI.Color.white.opacity(0.14)

        // ── Accent palette (richer, warmer mix) ──────────────────────────
        /// Primary: teal-green `#00C896`
        static let accent           = SwiftUI.Color(red: 0.0,   green: 0.784, blue: 0.588)
        /// Violet — screener / AI indicators
        static let violet           = SwiftUI.Color(red: 0.502, green: 0.333, blue: 0.961)
        /// Amber — sell / warning
        static let amber            = SwiftUI.Color(red: 1.0,   green: 0.675, blue: 0.149)
        /// Sky blue — secondary charts / sector tags
        static let sky              = SwiftUI.Color(red: 0.247, green: 0.655, blue: 0.988)
        /// Rose — loss / sell signal
        static let rose             = SwiftUI.Color(red: 0.988, green: 0.290, blue: 0.412)
        /// Gold — performance / earnings
        static let gold             = SwiftUI.Color(red: 0.969, green: 0.780, blue: 0.188)
        /// Mint — news / safe indicators
        static let mint             = SwiftUI.Color(red: 0.196, green: 0.902, blue: 0.694)
        /// Coral — allocation chart slice 3
        static let coral            = SwiftUI.Color(red: 1.0,   green: 0.475, blue: 0.369)

        // ── Semantic aliases ──────────────────────────────────────────────
        static let gain             = accent
        static let loss             = rose
        static let warning          = amber
        static let accentSecondary  = sky

        // ── Text ──────────────────────────────────────────────────────────
        static let textPrimary   = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color(white: 0.56)
        static let textTertiary  = SwiftUI.Color(white: 0.36)

        // ── Chart palette — used for allocation donut, legends ────────────
        static let chartPalette: [SwiftUI.Color] = [
            accent, violet, amber, sky, rose, gold, mint, coral,
            SwiftUI.Color(red: 0.6, green: 0.4, blue: 0.9),   // lavender
            SwiftUI.Color(red: 0.2, green: 0.8, blue: 0.6),   // seafoam
        ]
    }

    // MARK: Gradients
    enum Gradient {
        /// Ambient teal glow — top-leading
        static func ambientGreen(opacity: Double = 0.12) -> RadialGradient {
            RadialGradient(colors: [DS.Color.accent.opacity(opacity), .clear],
                           center: UnitPoint(x: 0.1, y: 0.0), startRadius: 5, endRadius: 360)
        }
        /// Ambient violet glow — top-trailing (replaces old cyan, warmer feel)
        static func ambientViolet(opacity: Double = 0.07) -> RadialGradient {
            RadialGradient(colors: [DS.Color.violet.opacity(opacity), .clear],
                           center: UnitPoint(x: 0.9, y: 0.25), startRadius: 5, endRadius: 320)
        }
        /// Ambient sky glow — bottom (depth)
        static func ambientSky(opacity: Double = 0.05) -> RadialGradient {
            RadialGradient(colors: [DS.Color.sky.opacity(opacity), .clear],
                           center: UnitPoint(x: 0.5, y: 1.0), startRadius: 5, endRadius: 280)
        }
        /// Hero card gradient fill — teal → violet tint
        static let heroCard = LinearGradient(
            colors: [DS.Color.accent.opacity(0.13), DS.Color.violet.opacity(0.06),
                     SwiftUI.Color.white.opacity(0.025)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Sell hero card — amber/rose tint
        static let sellCard = LinearGradient(
            colors: [DS.Color.rose.opacity(0.10), DS.Color.amber.opacity(0.06),
                     SwiftUI.Color.white.opacity(0.02)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Subtle row card gradient
        static let rowCard = LinearGradient(
            colors: [SwiftUI.Color.white.opacity(0.055), SwiftUI.Color.white.opacity(0.022)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Corner Radii
    enum Radius {
        static let small: CGFloat   = 10
        static let medium: CGFloat  = 14
        static let large: CGFloat   = 18
        static let xlarge: CGFloat  = 22
        static let xxlarge: CGFloat = 26
    }

    // MARK: Typography
    enum Font {
        static let portfolioValue = SwiftUI.Font.system(size: 38, weight: .bold, design: .rounded)
        static let priceValue     = SwiftUI.Font.system(size: 32, weight: .bold, design: .rounded)
        static func sectionLabel() -> SwiftUI.Font { SwiftUI.Font.system(size: 10, weight: .bold) }
    }
}

// MARK: - View Modifiers

extension View {
    /// Standard dark card
    func dsCard(radius: CGFloat = DS.Radius.large) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(DS.Color.border))
    }

    /// Hero gradient card — teal/violet
    func dsHeroCard(radius: CGFloat = DS.Radius.xlarge) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(DS.Gradient.heroCard, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius).stroke(
                    LinearGradient(colors: [DS.Color.accent.opacity(0.32), DS.Color.violet.opacity(0.18), DS.Color.border],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .shadow(color: DS.Color.accent.opacity(0.07), radius: 20, y: 10)
    }

    /// Sell-mode hero card — amber/rose
    func dsSellHeroCard(radius: CGFloat = DS.Radius.xlarge) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(DS.Gradient.sellCard, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius).stroke(
                    LinearGradient(colors: [DS.Color.rose.opacity(0.28), DS.Color.amber.opacity(0.15), DS.Color.border],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .shadow(color: DS.Color.rose.opacity(0.06), radius: 18, y: 8)
    }

    /// Three-glow app background
    func dsAppBackground() -> some View {
        self.background(
            ZStack(alignment: .top) {
                DS.Color.background.ignoresSafeArea()
                DS.Gradient.ambientGreen().frame(height: 500).ignoresSafeArea()
                DS.Gradient.ambientViolet().frame(height: 650).ignoresSafeArea()
                DS.Gradient.ambientSky().frame(height: 400).ignoresSafeArea()
            }
        )
    }
}

// MARK: - Shared Components

struct DSBadge: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color = DS.Color.accent) { self.text = text; self.color = color }
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold)).tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.25)))
    }
}

struct DSLiveDot: View {
    var color: Color = DS.Color.accent
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("LIVE").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(color)
        }
    }
}

struct DSSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(DS.Color.textSecondary)
            if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(DS.Color.textTertiary) }
        }
    }
}

struct DSStatTile: View {
    let icon: String
    let label: String
    let value: String
    var accent: Color = DS.Color.textPrimary
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
            Text(label).font(.caption).foregroundStyle(DS.Color.textSecondary)
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(DS.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.medium).stroke(DS.Color.border))
    }
}

struct DSPillPicker: View {
    let options: [String]
    @Binding var selected: String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selected = option }
                } label: {
                    Text(option)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected == option ? DS.Color.background : DS.Color.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selected == option ? DS.Color.accent : DS.Color.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
