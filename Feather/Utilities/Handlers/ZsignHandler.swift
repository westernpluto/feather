//
//  ZsignHandler.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import Foundation
import Zsign
import UIKit

final class ZsignHandler {
	var hadError: Error?
	
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	private var _multiProfile: MultiProfile?
	
	/// Feather fork: one provisioning profile (and entitlements file) per bundle.
	struct MultiProfile {
		var provisionPaths: [String]
		var entitlementsPaths: [String]
	}
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil,
		multiProfile: MultiProfile? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
		self._multiProfile = multiProfile
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		if !Zsign.removeDylibs(appExecutable: execPath, using: _options.disInjectionFiles) {
			throw SigningFileHandlerError.disinjectFailed
		}
	}
	
	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}
		
		if let multi = _multiProfile {
			let _ = Zsign.signMulti(
				appPath: _appUrl.relativePath,
				provisionPaths: multi.provisionPaths,
				entitlementsPaths: multi.entitlementsPaths,
				p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
				p12Password: cert.password ?? "",
				removeProvision: !_options.removeProvisioning,
				completion: { success in
					if !success {
						self.hadError = SigningFileHandlerError.signFailed
					}
				}
			)
			return
		}

		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
			p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
			p12Password: cert.password ?? "",
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
	
	func adhocSign() async throws {
		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			adhoc: true,
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
}
