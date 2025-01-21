import SwiftUI

struct LoginScreen: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoggedIn: Bool = false
    @AppStorage("currentUserId") var currentUserId: Int?

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Войти")

            Divider()
                .frame(height: 1)
                .background(Color.gray.opacity(0.3))

            Spacer()
                .frame(height: 16)

            VStack(alignment: .leading, spacing: 16) {
                SharedInputField(placeholder: "Логин", text: $username, isSecure: false)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Validators.isValidUsername(username) ? Color.clear : Color.red, lineWidth: 2)
                    )

                SharedInputField(placeholder: "Пароль", text: $password, isSecure: true)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Validators.isValidPassword(password) ? Color.clear : Color.red, lineWidth: 2)
                    )

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(.top, 8)
                }

                Button(action: {
                    handleLogin()
                }) {
                    Text("Продолжить")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidForm() ? Color.blue : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 16)
                .disabled(!isValidForm())
                NavigationLink("", destination: HomePage().navigationBarBackButtonHidden(true), isActive: $isLoggedIn)
            }
            .padding(.horizontal, 16)

            Spacer()

            Image("Cyclists")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipped()

            Image("AlternateRegistrationImage")
                .resizable()
                .scaledToFit()
                .frame(width: 87, height: 56)
                .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
    }

    private func handleLogin() {
        guard isValidForm() else {
            errorMessage = "Пожалуйста, проверьте логин и пароль."
            return
        }

        if let userId = DatabaseManager.shared.loginUser(username: username, password: password) {
            currentUserId = Int(userId) 
            errorMessage = nil
            isLoggedIn = true
        } else {
            errorMessage = "Неверный логин или пароль."
        }
    }

    private func isValidForm() -> Bool {
        return Validators.isValidUsername(username)
            && Validators.isValidPassword(password)
    }
}

struct SharedInputField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        } else {
            TextField(placeholder, text: $text)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
    }
}
