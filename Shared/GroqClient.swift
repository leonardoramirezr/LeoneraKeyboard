import Foundation

enum GroqError: LocalizedError {
    case missingAPIKey
    case invalidURL(String)
    case server(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Falta la API key de Groq. Configúrala en la app Leonera Keyboard › Dictado."
        case .invalidURL(let url):
            return "La URL de la API no es válida: \(url)"
        case .server(let status, let message):
            return message.isEmpty ? "La API respondió con el error \(status)." : "Error \(status): \(message)"
        case .invalidResponse:
            return "La API devolvió una respuesta inesperada."
        }
    }
}

/// Cliente mínimo de la API de Groq (compatible con OpenAI): voz a texto,
/// chat para mejorar la transcripción y lista de modelos.
struct GroqClient {
    var settings: DictationSettings
    var session: URLSession = .shared

    /// Envía el audio al modelo de voz a texto y devuelve la transcripción.
    func transcribe(audioAt fileURL: URL) async throws -> String {
        let audio = try Data(contentsOf: fileURL)
        var form = MultipartForm()
        form.addField("model", settings.effectiveTranscriptionModel)
        form.addField("response_format", "json")
        form.addField("temperature", "0")
        let language = settings.language.trimmingCharacters(in: .whitespacesAndNewlines)
        if !language.isEmpty {
            form.addField("language", language)
        }
        form.addFile("file", fileName: fileURL.lastPathComponent, mimeType: "audio/mp4", data: audio)

        var request = try makeRequest("audio/transcriptions")
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        let data = try await send(request, body: form.finalized())

        struct Response: Decodable { let text: String }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw GroqError.invalidResponse
        }
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Envía la transcripción al LLM con el prompt configurado y devuelve el texto mejorado.
    func improve(_ text: String) async throws -> String {
        struct Message: Codable { let role: String; let content: String? }
        struct ChatRequest: Encodable {
            let model: String
            let messages: [Message]
            let temperature: Double
            let reasoning_effort: String?
        }
        struct ChatResponse: Decodable {
            struct Choice: Decodable { let message: Message }
            let choices: [Choice]
        }

        let model = settings.effectiveLanguageModel
        let prompt = settings.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ChatRequest(
            model: model,
            messages: [
                Message(role: "system", content: prompt.isEmpty ? DictationSettings.defaultPrompt : prompt),
                Message(role: "user", content: text),
            ],
            temperature: 0.2,
            // Los modelos gpt-oss razonan antes de responder; para corregir un texto basta con poco.
            reasoning_effort: model.hasPrefix("openai/gpt-oss") ? "low" : nil
        )

        var request = try makeRequest("chat/completions")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data = try await send(request, body: try JSONEncoder().encode(body))

        guard let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = response.choices.first?.message.content
        else { throw GroqError.invalidResponse }
        return Self.removingReasoning(from: content).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Identificadores de los modelos disponibles para la API key, ordenados.
    func availableModels() async throws -> [String] {
        struct Response: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        var request = try makeRequest("models")
        request.httpMethod = "GET"
        let data = try await send(request, body: nil)
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw GroqError.invalidResponse
        }
        return response.data.map(\.id).sorted()
    }

    // MARK: - Peticiones

    private func makeRequest(_ path: String) throws -> URLRequest {
        let apiKey = settings.trimmedAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }
        let address = settings.baseURL + "/" + path
        guard let url = URL(string: address), url.scheme?.hasPrefix("http") == true else {
            throw GroqError.invalidURL(settings.baseURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest, body: Data?) async throws -> Data {
        let result: (Data, URLResponse)
        if let body {
            result = try await session.upload(for: request, from: body)
        } else {
            result = try await session.data(for: request)
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else { throw GroqError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw GroqError.server(status: http.statusCode, message: Self.errorMessage(in: data))
        }
        return data
    }

    /// Mensaje de error de una respuesta `{"error": {"message": "…"}}`.
    private static func errorMessage(in data: Data) -> String {
        struct ErrorResponse: Decodable {
            struct Detail: Decodable { let message: String? }
            let error: Detail?
        }
        if let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error?.message {
            return message
        }
        return String(decoding: data.prefix(300), as: UTF8.self)
    }

    /// Algunos modelos incluyen su razonamiento entre `<think>` y `</think>` en la respuesta.
    private static func removingReasoning(from text: String) -> String {
        guard let end = text.range(of: "</think>") else { return text }
        return String(text[end.upperBound...])
    }
}

/// Cuerpo `multipart/form-data` para subir el audio.
private struct MultipartForm {
    let boundary = "LeoneraBoundary-\(UUID().uuidString)"
    private var data = Data()

    mutating func addField(_ name: String, _ value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func addFile(_ name: String, fileName: String, mimeType: String, data fileData: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    func finalized() -> Data {
        var result = data
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }

    private mutating func append(_ string: String) {
        data.append(Data(string.utf8))
    }
}
