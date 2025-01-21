import SwiftUI

struct RegistrationScreen: View {
    @State private var username: String = ""
    @State private var nickname: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var gender: String = "-"
    @State private var isGenderValid: Bool = true
    @State private var showGenderPicker: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isRegistered: Bool = false

    @AppStorage("currentUserId") var currentUserId: Int?

    private let genderOptions = ["-", "Мужчина", "Женщина"]

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Регистрация")
            
            Divider()
                .frame(height: 1)
                .background(Color.gray.opacity(0.3))
            
            Spacer()
                .frame(height: 16)
            
            VStack(alignment: .leading, spacing: 16) {
                InputField(placeholder: "Логин", text: $username, isSecure: false)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Validators.isValidUsername(username) ? Color.clear : Color.red, lineWidth: 2)
                    )
                
                InputField(placeholder: "Имя или никнейм", text: $nickname, isSecure: false)
                
                InputField(placeholder: "Пароль", text: $password, isSecure: true)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Validators.isValidPassword(password) ? Color.clear : Color.red, lineWidth: 2)
                    )
                
                InputField(placeholder: "Повторите пароль", text: $confirmPassword, isSecure: true)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Validators.arePasswordsMatching(password, confirmPassword) ? Color.clear : Color.red, lineWidth: 2)
                    )
                
                HStack {
                    Text("Пол")
                    Spacer()
                    Text(gender)
                        .foregroundColor(isGenderValid ? .gray : .red)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .onTapGesture {
                    showGenderPicker = true
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(.top, 8)
                }
                
                Button(action: {
                    handleFormSubmission()
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
                NavigationLink("", destination: HomePage().navigationBarBackButtonHidden(true), isActive: $isRegistered)
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            Image("AlternateRegistrationImage")
                .resizable()
                .scaledToFit()
                .frame(width: 87, height: 56)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showGenderPicker) {
            VStack {
                Text("Выберите пол")
                    .font(.headline)
                    .padding()
                
                Picker("Пол", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .padding()
                
                Button("Готово") {
                    showGenderPicker = false
                    isGenderValid = gender != "-"
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
    }

    private func handleFormSubmission() {
        guard isValidForm() else {
            errorMessage = "Пожалуйста, проверьте введённые данные."
            return
        }

        let registrationSuccess = DatabaseManager.shared.registerUser(
            username: username,
            nickname: nickname,
            password: password,
            gender: gender
        )

        if registrationSuccess {
            errorMessage = nil
            isRegistered = true
            print("Регистрация успешна")
            if let userId = DatabaseManager.shared.loginUser(username: username, password: password) {
                currentUserId = Int(userId)
            }
        } else {
            errorMessage = "Ошибка регистрации. Попробуйте другой логин."
        }
    }

    private func isValidForm() -> Bool {
        return Validators.isValidUsername(username)
            && Validators.isValidPassword(password)
            && Validators.arePasswordsMatching(password, confirmPassword)
            && gender != "-"
    }
}

struct InputField: View {
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
