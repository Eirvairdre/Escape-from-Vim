import Foundation

struct Validators {
    static func isValidUsername(_ username: String) -> Bool {
        return !username.isEmpty && username.range(of: "^[a-zA-Z0-9]*$", options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        return !password.isEmpty && password.count >= 6
    }

    static func arePasswordsMatching(_ password: String, _ confirmPassword: String) -> Bool {
        return password == confirmPassword
    }
}
