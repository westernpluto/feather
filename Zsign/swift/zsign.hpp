//
//  zsign.hpp
//  feather
//
//  Created by HAHALOSAH on 5/22/24.
//

#ifndef zsign_hpp
#define zsign_hpp

#include <stdio.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

bool CheckIfSigned(NSString *filePath);
bool InjectDyLib(NSString *filePath, NSString *dylibPath, bool weakInject);
bool UninstallDylibs(NSString *filePath, NSArray<NSString *> *dylibPathsArray);
NSArray<NSString *> *ListDylibs(NSString *filePath);
bool ChangeDylibPath(NSString *filePath, NSString *oldPath, NSString *newPath);

int zsign(
	NSString *app,
	NSString *prov,
	NSString *key,
	NSString *pass,
	NSString *entitlement,
	NSString *bundleid,
	NSString *displayname,
	NSString *bundleversion,
	bool adhoc,
	bool dontGenerateEmbeddedMobileProvision,
	void(^completionHandler)(BOOL success)
);

/// Signs an app with one provisioning profile per bundle. `provs[0]` is the main
/// app's profile; the others are matched to app extensions (and nested apps) by
/// their application-identifier, so each bundle gets its own embedded profile
/// and entitlements. `entitlements[i]` (may be an empty string) pairs with `provs[i]`.
int zsignMulti(
	NSString *app,
	NSArray<NSString *> *provs,
	NSArray<NSString *> *entitlements,
	NSString *key,
	NSString *pass,
	bool dontGenerateEmbeddedMobileProvision,
	void(^completionHandler)(BOOL success)
);

int checkCert(
	NSString *prov,
	NSString *key,
	NSString *pass,
	void(^completionHandler)(int status, NSDate* expirationDate, NSString *error)
);

#ifdef __cplusplus
}
#endif

#endif /* zsign_hpp */
