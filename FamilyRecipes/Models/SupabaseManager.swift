import Foundation

final class SupabaseManager {
    static let shared = SupabaseManager()
    
    private init() {}
    
    // Core HTTP Request Helper
    private func performRequest(
        urlPath: String,
        method: String,
        body: Data? = nil,
        supabaseURL: String,
        supabaseKey: String
    ) async throws -> Data {
        guard var components = URLComponents(string: supabaseURL) else {
            throw URLError(.badURL)
        }
        
        // Correctly split path and query parameters to prevent percent-encoding of '?' and '='
        let pathAndQuery = urlPath.split(separator: "?")
        let path = String(pathAndQuery[0])
        
        var fullPath = components.path
        if fullPath.hasSuffix("/") {
            fullPath.removeLast()
        }
        fullPath += "/rest/v1/\(path)"
        components.path = fullPath
        
        if pathAndQuery.count > 1 {
            let queryItems = String(pathAndQuery[1]).components(separatedBy: "&").map { item -> URLQueryItem in
                let parts = item.split(separator: "=")
                let name = String(parts[0])
                let value = parts.count > 1 ? String(parts[1]) : ""
                // Decode percent encoded query items if any
                return URLQueryItem(name: name, value: value.removingPercentEncoding ?? value)
            }
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Supabase Headers
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        if method == "POST" || method == "PATCH" {
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
    
    // MARK: - Family Member Sync API
    
    func fetchMembers(url: String, key: String) async throws -> [FamilyMember] {
        let data = try await performRequest(urlPath: "family_members?select=*", method: "GET", supabaseURL: url, supabaseKey: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([FamilyMember].self, from: data)
    }
    
    func upsertMember(_ member: FamilyMember, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(member)
        _ = try await performRequest(urlPath: "family_members", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteMember(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "family_members?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Dishes Sync API
    
    func fetchDishes(url: String, key: String) async throws -> [Dish] {
        let data = try await performRequest(urlPath: "dishes?select=*", method: "GET", supabaseURL: url, supabaseKey: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Dish].self, from: data)
    }
    
    func upsertDish(_ dish: Dish, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(dish)
        _ = try await performRequest(urlPath: "dishes", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteDish(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "dishes?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Meal Orders Sync API
    
    func fetchOrders(url: String, key: String) async throws -> [MealOrder] {
        let data = try await performRequest(urlPath: "meal_orders?select=*", method: "GET", supabaseURL: url, supabaseKey: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MealOrder].self, from: data)
    }
    
    func upsertOrder(_ order: MealOrder, url: String, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(order)
        _ = try await performRequest(urlPath: "meal_orders", method: "POST", body: body, supabaseURL: url, supabaseKey: key)
    }
    
    func deleteOrder(id: UUID, url: String, key: String) async throws {
        _ = try await performRequest(urlPath: "meal_orders?id=eq.\(id.uuidString.lowercased())", method: "DELETE", supabaseURL: url, supabaseKey: key)
    }
}
