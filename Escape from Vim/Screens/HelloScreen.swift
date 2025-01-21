import SwiftUI

struct HelloScreen: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 111)

                    Text("Пожалуй лучший фитнес трекер в ДВФУ")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("Созданный студентами 2-ого курса")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    NavigationLink(destination: RegistrationScreen()) {
                        Text("Зарегистрироваться")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: LoginScreen()) {
                        Text("Уже есть аккаунт?")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.white]),
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
    }
}

struct HelloScreen_Previews: PreviewProvider {
    static var previews: some View {
        HelloScreen()
    }
}
