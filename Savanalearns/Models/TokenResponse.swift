// Models/TokenResponse.swift
import Foundation

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}
