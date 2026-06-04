import Foundation

struct AIEngine {
    /// Generates a gourmet food photo using Stable Diffusion based on the dish name.
    /// Returns the raw JPEG image data.
    static func generateAIImage(for dishName: String) async throws -> Data {
        // Construct high-quality gourmet photography prompt
        let prompt = "exquisite delicious \(dishName) chinese food, gourmet photography, close-up shot, depth of field, warm cinematic lighting, high-resolution"
        
        guard let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://image.pollinations.ai/prompt/\(encodedPrompt)?width=512&height=512&nologo=true&seed=\(Int.random(in: 1...9999))"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20.0 // 20s timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
}
