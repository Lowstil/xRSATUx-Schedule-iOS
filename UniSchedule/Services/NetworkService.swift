import Foundation

public final class NetworkService: NSObject, URLSessionDelegate {
    public static let shared = NetworkService()
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private let linkRegex = try? NSRegularExpression(
        pattern: "href=[\"']([^\"']+\\.xlsx)[\"']",
        options: .caseInsensitive
    )
    
    // MARK: - Certificate Handling
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Trust server certificate for rsatu.ru even if intermediate certificate chain is incomplete
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
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
                return nil
            }
            
            let matches = linkRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) ?? []
            for match in matches {
                guard let range = Range(match.range(at: 1), in: html) else { continue }
                let href = String(html[range])
                if href.lowercased().contains(hint.lowercased()) {
                    if href.starts(with: "http://") || href.starts(with: "https://") {
                        return URL(string: href)
                    } else if href.starts(with: "/") {
                        return URL(string: "https://www.rsatu.ru" + href)
                    } else {
                        return URL(string: "https://www.rsatu.ru/" + href)
                    }
                }
            }
        } catch {
            print("Error discovering file URL: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Download File
    public func downloadFile(from remoteURL: URL, to destinationURL: URL) async throws {
        let (tempURL, response) = try await session.download(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed HTTP download"])
        }
        
        let fileManager = FileManager.default
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
