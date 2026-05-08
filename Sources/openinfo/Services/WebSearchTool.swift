import Foundation

// MARK: - Web Search Tool — DuckDuckGo Lite HTML search for real-time results

actor WebSearchTool {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
    }

    struct SearchResult {
        let title: String
        let snippet: String
        let url: String
    }

    /// Fetch real-time search results from DuckDuckGo Lite (HTML search).
    /// This returns actual web pages, not just Wikipedia summaries.
    func search(query: String) async -> [SearchResult] {
        // Try DuckDuckGo Lite first — real web search, no API key needed
        let ddgResults = await searchDuckDuckGoLite(query: query)
        if ddgResults.count >= 3 { return ddgResults }

        // Fallback: DuckDuckGo Instant Answer API (Wikipedia-style summaries)
        let apiResults = await searchDuckDuckGoAPI(query: query)

        // Merge: prefer lite results, supplement with API if lite was sparse
        let merged = ddgResults + apiResults.filter { api in
            !ddgResults.contains(where: { $0.url == api.url })
        }
        return merged.isEmpty ? [] : Array(merged.prefix(6))
    }

    // MARK: - DuckDuckGo Lite (HTML search — real web results)

    private func searchDuckDuckGoLite(query: String) async -> [SearchResult] {
        guard var components = URLComponents(string: "https://lite.duckduckgo.com/lite/") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "kl", value: "wt-wt"),  // worldwide
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await session.data(for: request),
              let html = String(data: data, encoding: .utf8)
        else { return [] }

        return parseDuckDuckGoLiteHTML(html)
    }

    /// Parse the DuckDuckGo Lite HTML response.
    /// The Lite page uses a simple table layout where results appear in groups of rows:
    ///   Row 1: link (title + URL),  Row 2: snippet,  Row 3: empty spacer
    private func parseDuckDuckGoLiteHTML(_ html: String) -> [SearchResult] {
        var results: [SearchResult] = []

        // Extract all <a class="result-link" ...> tags for titles and URLs
        let linkPattern = try? NSRegularExpression(pattern: "<a[^>]*class=\"result-link\"[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", options: .dotMatchesLineSeparators)
        // Extract snippet from <td class="result-snippet">
        let snippetPattern = try? NSRegularExpression(pattern: "<td[^>]*class=\"result-snippet\"[^>]*>(.*?)</td>", options: .dotMatchesLineSeparators)

        guard let linkRegex = linkPattern, let snippetRegex = snippetPattern else { return [] }

        let linkMatches = linkRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        let snippetMatches = snippetRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        // Pair links with snippets by order
        for i in 0..<min(linkMatches.count, snippetMatches.count) {
            let linkMatch = linkMatches[i]

            guard let urlRange = Range(linkMatch.range(at: 1), in: html),
                  let titleRange = Range(linkMatch.range(at: 2), in: html)
            else { continue }

            let url = String(html[urlRange])
            let rawTitle = String(html[titleRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let snippetMatch = snippetMatches[i]
            guard let snippetRange = Range(snippetMatch.range(at: 1), in: html) else { continue }
            let rawSnippet = String(html[snippetRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip ad results (duckduckgo ads have /?q= or uddg= patterns)
            if url.contains("//ad.") || rawTitle.isEmpty { continue }

            results.append(SearchResult(title: rawTitle, snippet: rawSnippet, url: url))
        }

        return Array(results.prefix(6))
    }

    // MARK: - DuckDuckGo Instant Answer API (Wikipedia-style fallback)

    private func searchDuckDuckGoAPI(query: String) async -> [SearchResult] {
        guard var components = URLComponents(string: "https://api.duckduckgo.com/") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1"),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("openinfo/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        var results: [SearchResult] = []

        if let abstract = json["Abstract"] as? String, !abstract.isEmpty,
           let abstractURL = json["AbstractURL"] as? String {
            results.append(SearchResult(
                title: json["Heading"] as? String ?? query,
                snippet: abstract,
                url: abstractURL
            ))
        }

        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in topics.prefix(3) {
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
            return ""
        }
        var lines = ["Web search results for \"\(query)\":"]
        for (i, r) in results.enumerated() {
            lines.append("\(i+1). \(r.title)\n   \(r.snippet)")
        }
        lines.append("Use the above web results to answer the user's question with current, up-to-date information.")
        return lines.joined(separator: "\n")
    }
}