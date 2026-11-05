//
//  Storage+ExtensionProfiles.swift
//  Feather
//
//  Extra provisioning profiles stored next to a certificate, used to sign app
//  extensions (PlugIns/*.appex) with their own App IDs instead of the main
//  app's profile. Needed for extensions that use push, keychain sharing, etc.
//

import Foundation

extension Storage {
	private static let extensionProfilesFolder = "ExtensionProfiles"

	func extensionProfilesDirectory(for cert: CertificatePair) -> URL? {
		guard let base = getUuidDirectory(for: cert) else { return nil }
		let url = base.appendingPathComponent(Self.extensionProfilesFolder, isDirectory: true)
		try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}

	/// All extension profiles saved for this certificate, sorted by name.
	func getExtensionProfiles(for cert: CertificatePair) -> [URL] {
		guard
			let dir = extensionProfilesDirectory(for: cert),
			let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
		else {
			return []
		}
		return files
			.filter { $0.pathExtension.lowercased() == "mobileprovision" }
			.sorted { $0.lastPathComponent < $1.lastPathComponent }
	}

	enum ExtensionProfileError: LocalizedError {
		case unreadable
		case differentTeam(String)

		var errorDescription: String? {
			switch self {
			case .unreadable:
				return "This file isn't a readable provisioning profile."
			case .differentTeam(let team):
				return "This profile belongs to a different team (\(team)) than the certificate."
			}
		}
	}

	/// Copies a provisioning profile into this certificate's extension profiles.
	func addExtensionProfile(from source: URL, to cert: CertificatePair) throws {
		guard let decoded = CertificateReader(source).decoded else {
			throw ExtensionProfileError.unreadable
		}
		if
			let mainTeam = getProvisionFileDecoded(for: cert)?.TeamIdentifier.first,
			let team = decoded.TeamIdentifier.first,
			team != mainTeam
		{
			throw ExtensionProfileError.differentTeam(team)
		}
		guard let dir = extensionProfilesDirectory(for: cert) else {
			throw ExtensionProfileError.unreadable
		}
		let destination = dir.appendingPathComponent("\(decoded.UUID).mobileprovision")
		try? FileManager.default.removeItem(at: destination)
		try FileManager.default.copyItem(at: source, to: destination)
	}

	func removeExtensionProfile(_ url: URL) {
		try? FileManager.default.removeItem(at: url)
	}
}

extension Certificate {
	/// "TEAMID.com.example.app" from the profile's entitlements.
	var applicationIdentifier: String? {
		Entitlements?["application-identifier"]?.value as? String
	}

	/// The bundle ID this profile is for ("com.example.app", or "*" for wildcard profiles).
	var bundleIdentifier: String? {
		guard let appID = applicationIdentifier, let dot = appID.firstIndex(of: ".") else { return nil }
		return String(appID[appID.index(after: dot)...])
	}

	/// Whether this profile can sign a bundle with the given identifier.
	func matches(bundleIdentifier id: String) -> Bool {
		guard let pattern = bundleIdentifier else { return false }
		if pattern == id { return true }
		if pattern.hasSuffix("*") {
			return id.hasPrefix(String(pattern.dropLast()))
		}
		return false
	}
}
