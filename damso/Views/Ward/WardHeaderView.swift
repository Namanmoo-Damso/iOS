//
//  WardHeaderView.swift
//  damso
//
//  Created by Claude Code on 2024-12-30.
//

import SwiftUI

/// 어르신 홈 화면 헤더
struct WardHeaderView: View {
    let user: UserMeResponse?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "좋은 아침이에요"
        case 12..<17:
            return "안녕하세요"
        case 17..<21:
            return "좋은 저녁이에요"
        default:
            return "안녕하세요"
        }
    }

    private var nickname: String {
        user?.nickname ?? "사용자"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(nickname)님!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("오늘 기분은 어떠신가요?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 프로필 이미지
            AsyncImage(url: URL(string: user?.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}