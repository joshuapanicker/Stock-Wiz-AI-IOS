import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var email = ""; @State private var password = ""; @State private var creating = false
    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.028, blue: 0.035).ignoresSafeArea()
            RadialGradient(colors: [Color.green.opacity(0.16), .clear], center: .topTrailing, startRadius: 10, endRadius: 430).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        ZStack { RoundedRectangle(cornerRadius: 22).fill(Color.green.opacity(0.13)).frame(width: 76, height: 76); Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 34)).foregroundStyle(.green) }
                        Text("StockWiz").font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("AI-powered market intelligence, screening, and portfolio decisions.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    HStack { feature("sparkles", "Agentic screening"); feature("briefcase", "Portfolio signals"); feature("bubble.left", "Market AI") }
                    VStack(spacing: 16) {
                        Text(creating ? "Create your account" : "Welcome back").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        field("Email", icon: "envelope", secure: false, text: $email)
                        field("Password", icon: "lock", secure: true, text: $password)
                        if let message = authStore.errorMessage { Text(message).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
                        Button { Task { if creating { await authStore.signUp(email: email, password: password) } else { await authStore.signIn(email: email, password: password) } } } label: { HStack { Spacer(); if authStore.isLoading { ProgressView().tint(.black) } else { Text(creating ? "Create Account" : "Sign In").fontWeight(.semibold) }; Spacer() }.padding(.vertical, 5) }.buttonStyle(.borderedProminent).tint(.green).disabled(email.isEmpty || password.count < 6 || authStore.isLoading)
                        Button(creating ? "Already have an account? Sign in" : "New to StockWiz? Create an account") { withAnimation { creating.toggle() } }.foregroundStyle(.secondary)
                    }.padding(22).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
                    Text("Market information and AI output are educational, not financial advice.").font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                }.padding(24).padding(.top, 26)
            }
        }
    }
    private func feature(_ icon: String, _ title: String) -> some View { VStack(spacing: 7) { Image(systemName: icon).foregroundStyle(.green); Text(title).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity) }
    @ViewBuilder private func field(_ title: String, icon: String, secure: Bool, text: Binding<String>) -> some View { HStack { Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20); if secure { SecureField(title, text: text) } else { TextField(title, text: text).textInputAutocapitalization(.never).keyboardType(.emailAddress) } }.padding(14).background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.08))) }
}
