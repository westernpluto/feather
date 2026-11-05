//
//  AutoUpdateSigner.swift
//  Feather
//
//  Feather fork: one-tap (or automatic) updates for apps you already signed.
//  Downloads the update from its source, signs it with the same certificate and
//  your saved signing rules (Identifiers, Display Names, extension profiles),
//  then opens the install prompt, so you never re-enter a bundle ID.
//

import CoreData
import Foundation
import NimbleExtensions
import OSLog
import UIKit

@MainActor
final class AutoUpdateSigner: ObservableObject {
	static let shared = AutoUpdateSigner()

	/// Settings key: sign updates for signed apps as soon as an update check finds them.
	static let automaticKey = "feather.autoSignUpdates"

	private struct Pending {
		let localUUID: String
		let certificateUUID: String?
	}

	/// Download ID → what to sign it with.
	private var _pending: [String: Pending] = [:]
	/// Signed apps with an update in progress, so automatic checks don't start it twice.
	@Published private(set) var inProgress: Set<String> = []

	private init() {}

	/// Downloads `update` for the signed app `app`, then signs and offers to install it.
	func updateAndInstall(_ update: AppUpdate, for app: AppInfoPresentable) {
		guard !inProgress.contains(update.localUUID) else { return }
		let certificateUUID = (app as? Signed)?.certificate?.uuid
		let download = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "FeatherManualDownload_Update_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
		_pending[download.id] = Pending(localUUID: update.localUUID, certificateUUID: certificateUUID)
		inProgress.insert(update.localUUID)
		Logger.signing.info("Auto-update: downloading \(update.appName, privacy: .public) \(update.remoteVersion, privacy: .public)")
	}

	/// After an update check: start every signed app's update when automatic mode is on.
	func handleCheckResults(signedApps: [AppInfoPresentable]) {
		guard UserDefaults.standard.bool(forKey: Self.automaticKey) else { return }
		for app in signedApps {
			guard let update = UpdateManager.shared.update(for: app) else { continue }
			// The previous signed copy keeps reporting this update after we've signed
			// it; skip it once a signed copy of the new version is in the library.
			let alreadySigned = signedApps.contains {
				$0.identifier == app.identifier && $0.version == update.remoteVersion
			}
			guard !alreadySigned else { continue }
			updateAndInstall(update, for: app)
		}
	}

	/// Called by the download manager once a downloaded file is in the library.
	func importFinished(downloadID: String, importedUUID: String) {
		guard let pending = _pending.removeValue(forKey: downloadID) else { return }

		guard let imported = _importedApp(uuid: importedUUID) else {
			inProgress.remove(pending.localUUID)
			_fail("The update was downloaded, but Feather couldn't find it in your library.")
			return
		}

		let certificate = _certificate(uuid: pending.certificateUUID)
		guard certificate != nil else {
			inProgress.remove(pending.localUUID)
			_fail("The certificate this app was signed with is no longer in Feather. The update is in your library; sign it manually.")
			return
		}

		let options = _options(for: imported, certificate: certificate)
		FR.signPackageFile(imported, using: options, icon: nil, certificate: certificate) { error in
			self.inProgress.remove(pending.localUUID)
			if let error {
				self._fail("Couldn't sign the update: \(error.localizedDescription)")
				return
			}
			if options.post_deleteAppAfterSigned {
				Storage.shared.deleteApp(for: imported)
			}
			// LibraryView presents the install sheet for the newest signed app.
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
				NotificationCenter.default.post(name: Notification.Name("Feather.installApp"), object: nil)
			}
		}
	}

	// MARK: Helpers

	/// The same options SigningView starts from, with the saved replacement rules applied.
	private func _options(for app: AppInfoPresentable, certificate: CertificatePair?) -> Options {
		let saved = OptionsManager.shared.options
		var options = saved
		if
			saved.ppqProtection,
			let identifier = app.identifier,
			let certificate,
			certificate.ppQCheck
		{
			options.appIdentifier = "\(identifier).\(saved.ppqString)"
		}
		if let identifier = app.identifier, let replacement = saved.identifiers[identifier] {
			options.appIdentifier = replacement
		}
		if let name = app.name, let replacement = saved.displayNames[name] {
			options.appName = replacement
		}
		return options
	}

	private func _importedApp(uuid: String) -> Imported? {
		let request = NSFetchRequest<Imported>(entityName: "Imported")
		request.predicate = NSPredicate(format: "uuid == %@", uuid)
		request.fetchLimit = 1
		return try? Storage.shared.context.fetch(request).first
	}

	private func _certificate(uuid: String?) -> CertificatePair? {
		let request = NSFetchRequest<CertificatePair>(entityName: "CertificatePair")
		if let uuid {
			request.predicate = NSPredicate(format: "uuid == %@", uuid)
			request.fetchLimit = 1
			return try? Storage.shared.context.fetch(request).first
		}
		// Unknown (e.g. signed before this was tracked): use the certificate selected in Feather.
		request.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
		let all = (try? Storage.shared.context.fetch(request)) ?? []
		let selected = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		return all.indices.contains(selected) ? all[selected] : nil
	}

	private func _fail(_ message: String) {
		Logger.signing.error("Auto-update: \(message, privacy: .public)")
		UINotificationFeedbackGenerator().notificationOccurred(.error)
		UIAlertController.showAlertWithOk(title: "Update", message: message, isCancel: true)
	}
}
