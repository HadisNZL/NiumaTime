import CryptoKit
import Foundation

struct AppReleaseAsset: Equatable, Sendable {
    let name: String
    let downloadURL: URL
}

struct AppRelease: Equatable, Sendable {
    let version: String
    let title: String
    let pageURL: URL
    let archive: AppReleaseAsset?
    let checksum: AppReleaseAsset?

    var canDownloadSecurely: Bool {
        archive != nil && checksum != nil
    }
}

enum AppVersionComparison {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = numericComponents(in: candidate)
        let currentParts = numericComponents(in: current)
        guard !candidateParts.isEmpty, !currentParts.isEmpty else { return false }

        let count = max(candidateParts.count, currentParts.count)
        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }
        return false
    }

    private static func numericComponents(in value: String) -> [Int] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.first == "v" || trimmed.first == "V"
            ? String(trimmed.dropFirst())
            : trimmed

        return withoutPrefix.split(separator: ".").compactMap { component in
            let digits = component.prefix(while: { $0.isNumber })
            guard !digits.isEmpty else { return nil }
            return Int(digits)
        }
    }
}

enum AppUpdateChecker {
    static let projectURL = URL(string: "https://github.com/HadisNZL/NiumaTime")!
    static let releasesURL = projectURL.appendingPathComponent("releases")
    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/HadisNZL/NiumaTime/releases/latest"
    )!

    static func latestRelease() async throws -> AppRelease {
        let (data, response) = try await URLSession.shared.data(for: request(for: latestReleaseAPI))
        try validate(response)

        let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
        let assets = payload.assets.map {
            AppReleaseAsset(name: $0.name, downloadURL: $0.downloadURL)
        }
        let downloads = preferredDownloadAssets(in: assets)
        return AppRelease(
            version: payload.tagName,
            title: payload.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? payload.tagName,
            pageURL: payload.htmlURL,
            archive: downloads?.archive,
            checksum: downloads?.checksum
        )
    }

    static func download(_ release: AppRelease) async throws -> URL {
        guard let archive = release.archive, let checksum = release.checksum else {
            throw AppUpdateError.missingSecureDownload
        }

        async let archiveResult = URLSession.shared.download(for: request(for: archive.downloadURL))
        async let checksumResult = URLSession.shared.data(for: request(for: checksum.downloadURL))
        let ((temporaryURL, archiveResponse), (checksumData, checksumResponse)) = try await (
            archiveResult,
            checksumResult
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try validate(archiveResponse)
        try validate(checksumResponse)
        let expected = try expectedSHA256(from: checksumData)
        let actual = try sha256(of: temporaryURL)
        guard actual == expected else {
            throw AppUpdateError.checksumMismatch
        }

        let destination = try availableDownloadURL(named: archive.name)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func preferredDownloadAssets(
        in assets: [AppReleaseAsset]
    ) -> (archive: AppReleaseAsset, checksum: AppReleaseAsset)? {
        let archives = assets.filter { $0.name.lowercased().hasSuffix(".zip") }
        guard let archive = archives.first(where: {
            $0.name.localizedCaseInsensitiveContains("universal")
        }) ?? archives.first else { return nil }

        let checksumName = archive.name + ".sha256"
        guard let checksum = assets.first(where: {
            $0.name.caseInsensitiveCompare(checksumName) == .orderedSame
        }) ?? assets.first(where: {
            $0.name.lowercased().hasSuffix(".sha256")
        }) else { return nil }
        return (archive, checksum)
    }

    static func expectedSHA256(from data: Data) throws -> String {
        guard let text = String(data: data, encoding: .utf8),
              let candidate = text.split(whereSeparator: { $0.isWhitespace }).first
        else { throw AppUpdateError.invalidChecksum }

        let checksum = candidate.lowercased()
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        guard checksum.count == 64,
              checksum.unicodeScalars.allSatisfy(allowed.contains)
        else { throw AppUpdateError.invalidChecksum }
        return checksum
    }

    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NiumaTime-update-check", forHTTPHeaderField: "User-Agent")
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateError.invalidResponse
        }
        if httpResponse.statusCode == 404 {
            throw AppUpdateError.noPublishedRelease
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateError.server(httpResponse.statusCode)
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func availableDownloadURL(named rawName: String) throws -> URL {
        let fileManager = FileManager.default
        guard let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw AppUpdateError.downloadDirectoryUnavailable
        }
        try fileManager.createDirectory(at: downloads, withIntermediateDirectories: true)

        let safeName = URL(fileURLWithPath: rawName).lastPathComponent
        let base = (safeName as NSString).deletingPathExtension
        let ext = (safeName as NSString).pathExtension
        var candidate = downloads.appendingPathComponent(safeName)
        var copy = 2
        while fileManager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(copy)" : "\(base) \(copy).\(ext)"
            candidate = downloads.appendingPathComponent(name)
            copy += 1
        }
        return candidate
    }
}

enum AppUpdateError: LocalizedError {
    case invalidResponse
    case noPublishedRelease
    case server(Int)
    case missingSecureDownload
    case invalidChecksum
    case checksumMismatch
    case downloadDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "GitHub 返回的数据无法识别，请稍后重试。"
        case .noPublishedRelease:
            "项目暂未发布可下载的正式版本。"
        case let .server(code):
            "访问 GitHub 失败（状态码：\(code)）。"
        case .missingSecureDownload:
            "该版本没有完整的安装包或校验文件，请打开发布页下载。"
        case .invalidChecksum:
            "新版校验文件格式不正确，已停止下载。"
        case .checksumMismatch:
            "下载文件校验失败，已停止安装。"
        case .downloadDirectoryUnavailable:
            "无法访问下载文件夹。"
        }
    }
}

private struct GitHubReleasePayload: Decodable {
    struct Asset: Decodable {
        let name: String
        let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
