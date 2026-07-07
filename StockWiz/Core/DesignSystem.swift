import SwiftUI

// MARK: - Design System — "Pulse"
// Central design tokens for StockWiz iOS.
// Deep-space ground, breathing aurora ambience, layered glass surfaces,
// and a single living accent (pulse teal) with violet reserved for AI.

enum DS {

    // MARK: Colors
    enum Color {
        /// Deep space background `#0B0D12`
        static let background   = SwiftUI.Color(red: 0.043, green: 0.051, blue: 0.071)
        /// Elevated opaque surface (sheets, menus) `#12151D`
        static let surface      = SwiftUI.Color(red: 0.071, green: 0.082, blue: 0.114)
        /// Higher-elevation opaque surface `#1A1E2A`
        static let surfaceHigh  = SwiftUI.Color(red: 0.102, green: 0.118, blue: 0.165)
        /// Stroke / divider on glass
        static let border       = SwiftUI.Color.white.opacity(0.10)
        /// Stronger border
        static let borderStrong = SwiftUI.Color.white.opacity(0.16)
        /// Subtle glass fill layered over material
        static let glassFill    = SwiftUI.Color.white.opacity(0.045)

        // ── Accent palette ────────────────────────────────────────────────
        /// Primary: pulse teal `#2EE6A8`
        static let accent           = SwiftUI.Color(red: 0.180, green: 0.902, blue: 0.659)
        /// Aurora violet — AI surfaces & screener `#8055F5`
        static let violet           = SwiftUI.Color(red: 0.502, green: 0.333, blue: 0.961)
        /// Amber — sell / warning
        static let amber            = SwiftUI.Color(red: 1.0,   green: 0.675, blue: 0.149)
        /// Sky blue — secondary charts / sector tags
        static let sky              = SwiftUI.Color(red: 0.247, green: 0.655, blue: 0.988)
        /// Rose — loss / sell signal `#FF5C7A`
        static let rose             = SwiftUI.Color(red: 1.0,   green: 0.361, blue: 0.478)
        /// Gold — performance / earnings
        static let gold             = SwiftUI.Color(red: 0.969, green: 0.780, blue: 0.188)
        /// Mint — news / safe indicators
        static let mint             = SwiftUI.Color(red: 0.196, green: 0.902, blue: 0.694)
        /// Coral — allocation chart slice
        static let coral            = SwiftUI.Color(red: 1.0,   green: 0.475, blue: 0.369)

        // ── Semantic aliases ──────────────────────────────────────────────
        static let gain             = accent
        static let loss             = rose
        static let warning          = amber
        static let accentSecondary  = sky

        // ── Text ──────────────────────────────────────────────────────────
        static let textPrimary   = SwiftUI.Color(red: 0.95, green: 0.96, blue: 0.98)
        static let textSecondary = SwiftUI.Color(white: 0.62)
        static let textTertiary  = SwiftUI.Color(white: 0.40)

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
        /// Ambient violet glow — top-trailing
        static func ambientViolet(opacity: Double = 0.07) -> RadialGradient {
            RadialGradient(colors: [DS.Color.violet.opacity(opacity), .clear],
                           center: UnitPoint(x: 0.9, y: 0.25), startRadius: 5, endRadius: 320)
        }
        /// Ambient sky glow — bottom (depth)
        static func ambientSky(opacity: Double = 0.05) -> RadialGradient {
            RadialGradient(colors: [DS.Color.sky.opacity(opacity), .clear],
                           center: UnitPoint(x: 0.5, y: 1.0), startRadius: 5, endRadius: 280)
        }
        /// Hero card gradient fill — teal → violet tint over glass
        static let heroCard = LinearGradient(
            colors: [DS.Color.accent.opacity(0.14), DS.Color.violet.opacity(0.07),
                     SwiftUI.Color.white.opacity(0.02)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Sell hero card — amber/rose tint
        static let sellCard = LinearGradient(
            colors: [DS.Color.rose.opacity(0.11), DS.Color.amber.opacity(0.06),
                     SwiftUI.Color.white.opacity(0.02)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Subtle row card gradient
        static let rowCard = LinearGradient(
            colors: [SwiftUI.Color.white.opacity(0.055), SwiftUI.Color.white.opacity(0.022)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// Signal gradient — reserved for "live" accents (AI writing, active states)
        static let signal = LinearGradient(
            colors: [DS.Color.accent, DS.Color.violet],
            startPoint: .leading, endPoint: .trailing
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
        static let portfolioValue = SwiftUI.Font.system(size: 40, weight: .bold, design: .rounded)
        static let priceValue     = SwiftUI.Font.system(size: 36, weight: .bold, design: .rounded)
        static func sectionLabel() -> SwiftUI.Font { SwiftUI.Font.system(size: 10, weight: .bold) }
    }
}

// MARK: - Aurora Background
// The signature "Pulse" ambience: slow-breathing color fields that make the
// app feel alive even at rest. Honors Reduce Motion.

struct DSAuroraBackground: View {
    /// Tint of the primary (top-leading) blob — shift it per screen context.
    var primary: Color = DS.Color.accent
    var secondary: Color = DS.Color.violet
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            DS.Color.background

            Circle()
                .fill(primary.opacity(0.16 * intensity))
                .frame(width: 340, height: 340)
                .blur(radius: 70)
                .offset(x: -110, y: breathe ? -180 : -150)
                .scaleEffect(breathe ? 1.15 : 1.0)

            Circle()
                .fill(secondary.opacity(0.10 * intensity))
                .frame(width: 300, height: 300)
                .blur(radius: 75)
                .offset(x: 140, y: breathe ? -40 : -80)
                .scaleEffect(breathe ? 1.0 : 1.12)

            Circle()
                .fill(DS.Color.sky.opacity(0.05 * intensity))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 30, y: 330)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Standard glass card — blurred material + faint fill + hairline stroke
    func dsCard(radius: CGFloat = DS.Radius.large, padding: CGFloat = 16) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(DS.Color.glassFill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(DS.Color.border))
    }

    /// Hero gradient card — teal/violet aurora glass
    func dsHeroCard(radius: CGFloat = DS.Radius.xlarge) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(DS.Gradient.heroCard, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius).stroke(
                    LinearGradient(colors: [DS.Color.accent.opacity(0.35), DS.Color.violet.opacity(0.20), DS.Color.border],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .shadow(color: DS.Color.accent.opacity(0.10), radius: 22, y: 10)
    }

    /// Sell-mode hero card — amber/rose glass
    func dsSellHeroCard(radius: CGFloat = DS.Radius.xlarge) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(DS.Gradient.sellCard, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius).stroke(
                    LinearGradient(colors: [DS.Color.rose.opacity(0.30), DS.Color.amber.opacity(0.16), DS.Color.border],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .shadow(color: DS.Color.rose.opacity(0.08), radius: 18, y: 8)
    }

    /// Breathing aurora app background
    func dsAppBackground(primary: Color = DS.Color.accent,
                         secondary: Color = DS.Color.violet,
                         intensity: Double = 1.0) -> some View {
        self.background(DSAuroraBackground(primary: primary, secondary: secondary, intensity: intensity))
    }
}

// MARK: - Shared Components

struct DSBadge: View {
    let text: String
    let color: Color
    var solid: Bool = false
    init(_ text: String, color: Color = DS.Color.accent, solid: Bool = false) {
        self.text = text; self.color = color; self.solid = solid
    }
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold)).tracking(0.8)
            .foregroundStyle(solid ? DS.Color.background : color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(solid ? color : color.opacity(0.13), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(solid ? 0 : 0.28)))
            .shadow(color: solid ? color.opacity(0.45) : .clear, radius: 8)
    }
}

struct DSLiveDot: View {
    var color: Color = DS.Color.accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
                .shadow(color: color.opacity(pulsing ? 0.9 : 0.3), radius: pulsing ? 5 : 2)
            Text("LIVE").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(color)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulsing = true }
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .background(DS.Color.glassFill, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = option }
                } label: {
                    Text(option)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected == option ? DS.Color.background : DS.Color.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            selected == option ? AnyShapeStyle(DS.Color.accent) : AnyShapeStyle(DS.Color.glassFill),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(selected == option ? .clear : DS.Color.border))
                        .shadow(color: selected == option ? DS.Color.accent.opacity(0.35) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Criteria Ring
// Radial gauge for "N of M rules met" — the Pulse signature for criteria.

struct DSCriteriaRing: View {
    let met: Int
    let total: Int
    var color: Color = DS.Color.accent
    var size: CGFloat = 54

    private var fraction: Double { total > 0 ? Double(met) / Double(total) : 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SwiftUI.Color.white.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(colors: [color.opacity(0.6), color], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * fraction)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 4)
            Text("\(met)/\(total)")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
