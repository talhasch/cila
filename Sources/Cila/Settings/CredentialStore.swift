import Foundation

/// Stores the API key in ~/Library/Application Support/Cila/credentials.json,
/// readable only by the current user (directory 0700, file 0600).
///
/// The Keychain was dropped on purpose: without an Apple Team ID, macOS ties
/// item access to each build's code hash and prompts on every rebuild/launch.
enum CredentialStore {
    private struct Credentials: Codable {
        var apiKey: String
    }

    private static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Cila", directoryHint: .isDirectory)
    }

    private static var fileURL: URL {
        directory.appending(path: "credentials.json")
    }

    static func readAPIKey() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let credentials = try? JSONDecoder().decode(Credentials.self, from: data)
        else { return nil }
        return credentials.apiKey.isEmpty ? nil : credentials.apiKey
    }

    /// Saves `apiKey`, or deletes the file when it's empty.
    static func saveAPIKey(_ apiKey: String) throws {
        let fileManager = FileManager.default
        do {
            guard !apiKey.isEmpty else {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                return
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

            // Write to a private temp file, then rename over the old one so the
            // key is never briefly world-readable or half-written.
            let data = try JSONEncoder().encode(Credentials(apiKey: apiKey))
            let tempURL = directory.appending(path: ".credentials-\(UUID().uuidString)")
            guard fileManager.createFile(atPath: tempURL.path, contents: data,
                                         attributes: [.posixPermissions: 0o600])
            else { throw CocoaError(.fileWriteUnknown) }
            guard rename(tempURL.path, fileURL.path) == 0 else {
                try? fileManager.removeItem(at: tempURL)
                throw CocoaError(.fileWriteUnknown)
            }
        } catch {
            throw CredentialStoreError(underlying: error)
        }
    }
}

struct CredentialStoreError: LocalizedError {
    let underlying: Error
    var errorDescription: String? {
        "Couldn't save the API key (\(underlying.localizedDescription))."
    }
}
