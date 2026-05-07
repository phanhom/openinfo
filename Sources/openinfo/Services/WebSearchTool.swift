import Foundation

// MARK: - Web Search Tool (DuckDuckGo Instant Answer API, no key required)

actor WebSearchTool {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: cfg)
    }

    struct SearchResult {
        let title: String
        let snippet: String
        let url: String
    }

    /// Returns top snippets for a query using DuckDuckGo.
    func search(query: String) async -> [SearchResult] {
        guard var components = URLComponents(string: "https://api.duckduckgo.com/") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "q",      value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html",value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1"),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("openinfo/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        var results: [SearchResult] = []

        // Abstract (main answer)
        if let abstract = json["Abstract"] as? String, !abstract.isEmpty,
           let abstractURL = json["AbstractURL"] as? String {
            results.append(SearchResult(
                title: json["Heading"] as? String ?? query,
                snippet: abstract,
                url: abstractURL
            ))
        }

        // Related topics
        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in topics.prefix(4) {
                if let text = topic["Text"] as? String, !text.isEmpty,
                   let firstURL = topic["FirstURL"] as? String {
                    results.append(SearchResult(
                        title: text.components(separatedBy: " - ").first ?? text,
                        snippet: text,
                        url: firstURL
                    ))
                }
            }
        }

        return results
    }

    /// Format results into a compact string for the AI context.
    func searchContext(query: String) async -> String {
        let results = await search(query: query)
        guard !results.isEmpty else {
            return "No web results found for: \(query)"
        }
        var lines = ["Web search results for \"\(query)\":"]
        for (i, r) in results.enumerated() {
            lines.append("\(i+1). \(r.title)\n   \(r.snippet)")
        }
        return lines.joined(separator: "\n")
    }
}
