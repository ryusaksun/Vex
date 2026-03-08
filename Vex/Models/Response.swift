import Foundation

struct Pagination: Codable, Sendable {
    let current: Int
    let total: Int
}

struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]
    let pagination: Pagination
    let fetchedAt: Date

    init(data: [T], pagination: Pagination) {
        self.data = data
        self.pagination = pagination
        self.fetchedAt = Date()
    }
}

struct EntityResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T
    let fetchedAt: Date

    init(data: T) {
        self.data = data
        self.fetchedAt = Date()
    }
}

struct CollectionResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]
    let fetchedAt: Date

    init(data: [T]) {
        self.data = data
        self.fetchedAt = Date()
    }
}

struct StatusResponse<T: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let message: String
    var data: T?

    init(success: Bool, message: String = "", data: T? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}
