import SwiftUI

struct HeaderView: View {
    let title: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(UIColor(red: 0.976, green: 0.976, blue: 0.976, alpha: 0.94))
                .edgesIgnoringSafeArea(.top)

            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                        .font(.system(size: 20, weight: .bold))
                        .padding(.leading, 16)
                }
                .padding(.top, 2)

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.leading, 16)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 80)
    }
}
