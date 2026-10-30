import Foundation

public final class NetworkService: NSObject, URLSessionDelegate {
    public static let shared = NetworkService()
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 UniSchedule/1.0",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7"
        ]
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private let linkRegex = try? NSRegularExpression(
        pattern: "href=[\"']([^\"']+\\.xlsx)[\"']",
        options: .caseInsensitive
    )
    
    // MARK: - Certificate Handling for rsatu.ru
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let host = challenge.protectionSpace.host.lowercased() as String?,
           host.contains("rsatu.ru"),
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - Discover Direct Download URL
    public func discoverFileURL(pageURL: String, hint: String) async -> URL? {
        guard let url = URL(string: pageURL) else { return nil }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
                return nil
            }
            
            let matches = linkRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) ?? []
            for match in matches {
                guard let range = Range(match.range(at: 1), in: html) else { continue }
                let href = String(html[range])
                if href.lowercased().contains(hint.lowercased()) {
                    return resolveURL(pageURL: pageURL, link: href)
                }
            }
            
            // If hint didn't match, return first .xlsx if any
            if let firstMatch = matches.first, let range = Range(firstMatch.range(at: 1), in: html) {
                let href = String(html[range])
                return resolveURL(pageURL: pageURL, link: href)
            }
        } catch {
            print("Error discovering file URL: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func resolveURL(pageURL: String, link: String) -> URL? {
        if link.starts(with: "http://") || link.starts(with: "https://") {
            return URL(string: link)
        }
        if let base = URL(string: pageURL), let resolved = URL(string: link, relativeTo: base) {
            return resolved.absoluteURL
        }
        return URL(string: "https://www.rsatu.ru" + (link.starts(with: "/") ? link : "/" + link))
    }
    
    // MARK: - Download File
    public func downloadFile(from remoteURL: URL, to destinationURL: URL) async throws {
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        
        let (tempURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP статус ошибки при загрузке"])
        }
        
        let fileManager = FileManager.default
        let dir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }
    
    // MARK: - Fetch Main Schedule
    public func fetchScheduleFile(cacheURL: URL) async throws {
        let remoteURL = await discoverFileURL(pageURL: Constants.schedulePageURL, hint: Constants.scheduleFilenameHint)
            ?? URL(string: Constants.scheduleFallbackURL)!
        
        try await downloadFile(from: remoteURL, to: cacheURL)
    }
    
    // MARK: - Fetch Transfers
    public func fetchTransfersFile(cacheURL: URL) async throws {
        let remoteURL = await discoverFileURL(pageURL: Constants.transfersPageURL, hint: Constants.transfersFilenameHint)
            ?? URL(string: Constants.transfersFallbackURL)!
        
        try await downloadFile(from: remoteURL, to: cacheURL)
    }
}
