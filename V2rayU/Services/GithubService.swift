//
//  GithubService.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import Foundation

protocol GithubServiceProtocol {
    func fetchReleases(repo: String) async throws -> [GithubRelease]
    func downloadReleaseAsset(url: URL, to destination: URL) async throws -> URL
}

final class GithubService: GithubServiceProtocol {
    
    func fetchReleases(repo: String) async throws -> [GithubRelease] {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=20")!
        logger.info("fetchReleases: \(url)")

        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let releases = try decoder.decode([GithubRelease].self, from: data)
            logger.info("fetchReleases-ok:  \(url) \(releases.count)")
            // 按时间倒序排序
            return releases.sorted { $0.publishedAt > $1.publishedAt }
        } catch {
            // 如果不是正常的 release 列表，可能是 GitHub 返回了错误信息
            do {
                let decoder = JSONDecoder()
                let apiError = try decoder.decode(GithubError.self, from: data)
                throw NSError(domain: "GithubService", code: -1, userInfo: [NSLocalizedDescriptionKey: "GitHub API error: \(apiError.message)\n\(apiError.documentationUrl)"])
            } catch {
                logger.info("fetchReleases-Error: \(url) \(error)")
                throw error
            }
        }
    }
    
    func downloadReleaseAsset(url: URL, to destination: URL) async throws -> URL {
        let (tmpURL, _) = try await URLSession.shared.download(from: url)
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tmpURL, to: destination)
        return destination
    }
}
