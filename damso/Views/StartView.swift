import SwiftUI

struct StartView: View {
    @Binding var isServerSelected: Bool
    
    let users = [
        ("권동민", "3.sodam.store"),
        ("김상연", "1.sodam.store"),
        ("문성수", "4.sodam.store"),
        ("배재완", "5.sodam.store"),
        ("임익화", "2.sodam.store"),
        ("배포서버", "sodam.store")
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Text("사용자 이름을 선택해주세요")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 60)
            
            VStack(spacing: 16) {
                ForEach(users, id: \.1) { name, domain in
                    Button(action: {
                        AppConfig.serverDomain = domain
                        AppConfig.selectedDeveloperName = name
                        // 김상연, 배포서버만 api. prefix 사용
                        AppConfig.usesApiPrefix = (name == "김상연" || name == "배포서버")
                        isServerSelected = true
                    }) {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name == "배포서버" ? Color.orange : Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}