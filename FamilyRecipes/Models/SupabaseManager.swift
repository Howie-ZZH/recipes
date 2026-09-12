import Foundation

final class SupabaseManager {
    static let shared = SupabaseManager()
    
    var mockMembers: [MemberDTO]?
    var mockDishes: [DishDTO]?
    var mockOrders: [OrderDTO]?
    var mockDiaries: [DiaryDTO]?
    
    private init() {}

    // MARK: - JSON Decoding

    // PostgREST serializes PostgreSQL `timestamptz` with microsecond precision
    // (e.g. "2026-07-11T03:20:48.71102+00:00"). Swift's built-in `.iso8601`
    // strategy rejects fractional seconds, so parse with a formatter that
    // accepts them and fall back to the strict form for columns written without
    // fractional seconds (e.g. "2026-07-09T15:07:03+00:00").
    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let strictDateFormatter = ISO8601DateFormatter()

    /// Builds a decoder that accepts PostgREST timestamps, including those with
    /// fractional seconds. Exposed for unit testing the real wire format.
    static func makeDecoder() -> JSONDecoder {
        let result = JSONDecoder()
        result.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = fractionalDateFormatter.date(from: raw) ?? strictDateFormatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO8601 date string, got: \(raw)"
            )
        }
        return result
    }

    // Core HTTP Request Helper
    func performRequest(
        urlPath: String,
        method: String,
        body: Data? = nil,
        supabaseURL: String,
        supabaseKey: String
    ) async throws -> Data {
        var safeURL = supabaseURL
        if !safeURL.hasPrefix("http://") && !safeURL.hasPrefix("https://") {
            safeURL = "http://" + safeURL
        }
        
        guard var components = URLComponents(string: safeURL) else {
            throw URLError(.badURL)
        }
        
        let pathAndQuery = urlPath.split(separator: "?")
        let path = String(pathAndQuery[0])
        
        var fullPath = components.path
        if fullPath.hasSuffix("/") {
            fullPath.removeLast()
        }
        
        if components.host?.contains("supabase.co") == true {
            fullPath += "/rest/v1/\(path)"
        } else {
            fullPath += "/\(path)"
        }
        
        components.path = fullPath
        
        if pathAndQuery.count > 1 {
            let queryString = String(pathAndQuery[1])
            let queryItems = queryString.components(separatedBy: "&").compactMap { item -> URLQueryItem? in
                guard let eqIndex = item.firstIndex(of: "=") else {
                    return URLQueryItem(name: item, value: nil)
                }
                let name = String(item[..<eqIndex])
                let rawValue = String(item[item.index(after: eqIndex)...])
                let value = rawValue.removingPercentEncoding ?? rawValue
                return URLQueryItem(name: name, value: value)
            }
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if supabaseKey.hasPrefix("eyJ") {
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        } else if !supabaseKey.isEmpty {
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        if method == "POST" {
            request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        } else if method == "PATCH" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("Supabase API Error [\(httpResponse.statusCode)]: \(errorMsg)")
            throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return data
    }
    
    // Helper to format ISO8601 query filter
    static func buildFetchPath(table: String, since: Date?) -> String {
        if let since = since {
            let dateStr = strictDateFormatter.string(from: since)
            return "\(table)?select=*&updated_at=gt.\(dateStr)"
        }
        return "\(table)?select=*"
    }
    
    // MARK: - Family Member Sync API
    
    func fetchMembers(url: String, key: String, since: Date? = nil) async throws -> [MemberDTO] {
        if let mock = mockMembers { return mock }
        let path = Self.buildFetchPath(table: "family_members", since: since)
        let data = try await performRequest(urlPath: path, method: "GET", supabaseURL: url, supabaseKey: key)
        return try Self.makeDecoder().decode([MemberDTO].self, from: data)
    }
    
    func upsertMember(_ member: MemberDTO, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(member)
        _ = try await performRequest(urlPath: "family_members", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteMember(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "family_members?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
    
    func softDeleteMember(id: UUID, url: String, key: String) async throws {
        let nowStr = Self.strictDateFormatter.string(from: Date())
        let payload: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "name": "已删除",
            "emoji": "👤",
            "role": "Member",
            "updated_at": nowStr,
            "deleted_at": nowStr
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await performRequest(urlPath: "family_members", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Dishes Sync API
    
    func fetchDishes(url: String, key: String, since: Date? = nil) async throws -> [DishDTO] {
        if let mock = mockDishes { return mock }
        let path = Self.buildFetchPath(table: "dishes", since: since)
        let data = try await performRequest(urlPath: path, method: "GET", supabaseURL: url, supabaseKey: key)
        return try Self.makeDecoder().decode([DishDTO].self, from: data)
    }
    
    func upsertDish(_ dish: DishDTO, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(dish)
        _ = try await performRequest(urlPath: "dishes", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteDish(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "dishes?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
    
    func softDeleteDish(id: UUID, url: String, key: String) async throws {
        let nowStr = Self.strictDateFormatter.string(from: Date())
        let payload: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "name": "已删除",
            "category": "其他",
            "tags": [],
            "emoji": "🍲",
            "dish_description": "",
            "ingredients": [],
            "cook_note": "",
            "is_favorite": false,
            "updated_at": nowStr,
            "deleted_at": nowStr
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await performRequest(urlPath: "dishes", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Meal Orders Sync API
    
    func fetchOrders(url: String, key: String, since: Date? = nil) async throws -> [OrderDTO] {
        if let mock = mockOrders { return mock }
        let path = Self.buildFetchPath(table: "meal_orders", since: since)
        let data = try await performRequest(urlPath: path, method: "GET", supabaseURL: url, supabaseKey: key)
        return try Self.makeDecoder().decode([OrderDTO].self, from: data)
    }
    
    func upsertOrder(_ order: OrderDTO, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(order)
        _ = try await performRequest(urlPath: "meal_orders", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteOrder(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "meal_orders?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
    
    func softDeleteOrder(id: UUID, url: String, key: String) async throws {
        let nowStr = Self.strictDateFormatter.string(from: Date())
        let payload: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "note": "",
            "is_fulfilled": true,
            "updated_at": nowStr,
            "deleted_at": nowStr
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await performRequest(urlPath: "meal_orders", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Food Diary Sync API
    
    func fetchDiaries(url: String, key: String, since: Date? = nil) async throws -> [DiaryDTO] {
        if let mock = mockDiaries { return mock }
        let path = Self.buildFetchPath(table: "food_diaries", since: since)
        let data = try await performRequest(urlPath: path, method: "GET", supabaseURL: url, supabaseKey: key)
        return try Self.makeDecoder().decode([DiaryDTO].self, from: data)
    }
    
    func upsertDiary(_ diary: DiaryDTO, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(diary)
        _ = try await performRequest(urlPath: "food_diaries", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteDiary(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "food_diaries?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
    
    func softDeleteDiary(id: UUID, url: String, key: String) async throws {
        let nowStr = Self.strictDateFormatter.string(from: Date())
        let payload: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "comment": "",
            "rating": 1,
            "diary_date": nowStr.prefix(10),
            "updated_at": nowStr,
            "deleted_at": nowStr
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await performRequest(urlPath: "food_diaries", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
}
