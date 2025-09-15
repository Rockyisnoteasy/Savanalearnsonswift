// Models/UserProfile.swift
import Foundation

// 这个 struct 对应你 Kotlin 代码里的 UserProfile data class
struct UserProfile: Codable {
    let id: Int
    let email: String

    // 我们暂时先不处理头像，让逻辑保持简单
    // let avatarUrls: AvatarUrls?
}
