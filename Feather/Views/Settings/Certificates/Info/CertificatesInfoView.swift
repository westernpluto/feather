//
//  CertificatesInfoView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews
import Zsign

// MARK: - View
struct CertificatesInfoView: View {
	@Environment(\.dismiss) var dismiss
	@State var data: Certificate?
	@State private var _extensionProfiles: [URL] = []
	@State private var _isImportingProfile = false
	@State private var _profileError: String?
	
	var cert: CertificatePair
	
	// MARK: Body
	var body: some View {
		NBNavigationView(cert.nickname ?? "", displayMode: .inline) {
			Form {
				Section {} header: {
					Image("Cert")
						.resizable()
						.scaledToFit()
						.frame(width: 107, height: 107)
						.frame(maxWidth: .infinity, alignment: .center)
				}
				
				if let data {
					_infoSection(data: data)
					_entitlementsSection(data: data)
					_miscSection(data: data)
				}
				
				_extensionProfilesSection
				
				Section {
					Button(.localized("Open in Files"), systemImage: "folder") {
						UIApplication.open(Storage.shared.getUuidDirectory(for: cert)!.toSharedDocumentsURL()!)
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
		.onAppear {
			data = Storage.shared.getProvisionFileDecoded(for: cert)
			_reloadExtensionProfiles()
		}
		.fileImporter(isPresented: $_isImportingProfile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
			guard case .success(let urls) = result else { return }
			_profileError = nil
			for url in urls {
				let scoped = url.startAccessingSecurityScopedResource()
				defer { if scoped { url.stopAccessingSecurityScopedResource() } }
				do {
					try Storage.shared.addExtensionProfile(from: url, to: cert)
				} catch {
					_profileError = error.localizedDescription
				}
			}
			_reloadExtensionProfiles()
		}
	}
}

// MARK: - Extension: Extension profiles (Feather fork)
extension CertificatesInfoView {
	private func _reloadExtensionProfiles() {
		_extensionProfiles = Storage.shared.getExtensionProfiles(for: cert)
	}
	
	@ViewBuilder
	private var _extensionProfilesSection: some View {
		Section {
			ForEach(_extensionProfiles, id: \.self) { url in
				let decoded = CertificateReader(url).decoded
				VStack(alignment: .leading, spacing: 2) {
					Text(verbatim: decoded?.Name ?? url.lastPathComponent)
					Text(verbatim: decoded?.bundleIdentifier ?? "")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				.swipeActions {
					Button(role: .destructive) {
						Storage.shared.removeExtensionProfile(url)
						_reloadExtensionProfiles()
					} label: {
						Label(String.localized("Delete"), systemImage: "trash")
					}
				}
			}
			Button(String.localized("Add Extension Profile"), systemImage: "plus") {
				_isImportingProfile = true
			}
			if let _profileError {
				Text(verbatim: _profileError)
					.font(.footnote)
					.foregroundStyle(.red)
			}
		} header: {
			Text(String.localized("Extension Profiles"))
		} footer: {
			Text(String.localized("Profiles for app extensions, such as a notification service. When signing, each extension whose bundle ID exactly matches one of these profiles is signed with it and its own entitlements, instead of this certificate's main profile. Make each profile from the same team and certificate."))
		}
	}
}

// MARK: - Extension: View
extension CertificatesInfoView {
	@ViewBuilder
	private func _infoSection(data: Certificate) -> some View {
		NBSection(.localized("Info")) {
			_info(.localized("Name"), description: data.Name)
			_info(.localized("AppID Name"), description: data.AppIDName)
			_info(.localized("Team Name"), description: data.TeamName)
		}
		
		Section {
			_info(.localized("Expires"), description: data.ExpirationDate.expirationInfo().formatted)
				.foregroundStyle(data.ExpirationDate.expirationInfo().color)
			
			_info(.localized("Revoked"), description: cert.revoked ? "✓" : "✗")
			
			if let ppq = data.PPQCheck {
				_info(.localized("PPQCheck"), description: ppq ? "✓" : "✗")
			}
		}
	}
	
	@ViewBuilder
	private func _entitlementsSection(data: Certificate) -> some View {
		if let entitlements = data.Entitlements {
			Section {
				NavigationLink(.localized("View Entitlements")) {
					CertificatesInfoEntitlementView(entitlements: entitlements)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _miscSection(data: Certificate) -> some View {
		NBSection(.localized("Misc")) {
			_disclosure(.localized("Platform"), keys: data.Platform)
			
			if let all = data.ProvisionsAllDevices {
				_info(.localized("Provision All Devices"), description: all.description)
			}
			
			if let devices = data.ProvisionedDevices {
				_disclosure(.localized("Provisioned Devices"), keys: devices)
			}
			
			_disclosure(.localized("Team Identifiers"), keys: data.TeamIdentifier)
			
			if let prefix = data.ApplicationIdentifierPrefix{
				_disclosure(.localized("Identifier Prefix"), keys: prefix)
			}
		}
	}
	
	@ViewBuilder
	private func _info(_ title: String, description: String) -> some View {
		LabeledContent(title) {
			Text(description)
		}
		.copyableText(description)
	}
	
	@ViewBuilder
	private func _disclosure(_ title: String, keys: [String]) -> some View {
		DisclosureGroup(title) {
			ForEach(keys, id: \.self) { key in
				Text(key)
					.foregroundStyle(.secondary)
					.copyableText(key)
			}
		}
	}
}
