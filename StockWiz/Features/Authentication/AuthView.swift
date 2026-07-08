import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var email = ""
    @State private var password = ""
    @State private var creating = false

    var body: some View {
        ZStack {
            DSAuroraBackground(intensity: 0.7)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // MARK: Brand header
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.large)
                                .fill(DS.Color.accent.opacity(0.12))
                                .frame(width: 72, height: 72)
                            RoundedRectangle(cornerRadius: DS.Radius.large)
                                .stroke(DS.Color.accent.opacity(0.3))
                                .frame(width: 72, height: 72)
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(DS.Color.accent)
                        }

                        VStack(spacing: 6) {
                            Text("StockWiz")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("AI-powered market intelligence")
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 28)

                    // MARK: Feature pills
                    HStack(spacing: 0) {
                        featurePill("sparkles", "AI Screening")
                        featurePill("briefcase.fill", "Portfolio")
                        featurePill("bubble.left.fill", "Market Chat")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.large))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.large).stroke(DS.Color.border))

                    // MARK: Auth card
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(creating ? "Create your account" : "Welcome back")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(creating ? "Get started in seconds." : "Sign in to continue.")
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        authField("Email address", icon: "envelope.fill", secure: false, text: $email)
                        authField("Password", icon: "lock.fill", secure: true, text: $password)

                        if let message = authStore.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text(message)
                                    .font(.caption)
                            }
                            .foregroundStyle(DS.Color.loss)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(DS.Color.loss.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                        }

                        // Submit button
                        Button {
                            Task {
                                if creating {
                                    await authStore.signUp(email: email, password: password)
                                } else {
                                    await authStore.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if authStore.isLoading {
                                    ProgressView()
                                        .tint(DS.Color.background)
                                        .controlSize(.small)
                                } else {
                                    Text(creating ? "Create Account" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(DS.Color.background)
                                }
                                Spacer()
                            }
                            .frame(height: 50)
                            .background(DS.Color.accent, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                        }
                        .disabled(email.isEmpty || password.count < 6 || authStore.isLoading)
                        .opacity(email.isEmpty || password.count < 6 ? 0.5 : 1)
                        .animation(.easeInOut(duration: 0.15), value: email.isEmpty || password.count < 6)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { creating.toggle() }
                        } label: {
                            Text(creating ? "Already have an account? Sign in" : "New to StockWiz? Create an account")
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.accent)
                        }
                    }
                    .padding(22)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xlarge))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.xlarge).stroke(DS.Color.border))

                    Text("Market data and AI output are for educational purposes only, not financial advice.")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func featurePill(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.Color.accent)
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func authField(_ title: String, icon: String, secure: Bool, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: 20)
            if secure {
                SecureField(title, text: text)
                    .font(.subheadline)
            } else {
                TextField(title, text: text)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .background(DS.Color.background, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.medium)
                .stroke(DS.Color.border)
        )
    }
}
