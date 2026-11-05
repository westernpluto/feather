"""Writes an AltStore-style source listing this fork's newest Feather build, so
Feather can update itself with its own "Update & Install" / automatic updates.

Usage: feather_source.py <owner/repo> <version> <build> <release tag> <ipa path> <output path>
"""
import datetime
import json
import os
import sys

repo, version, build, tag, ipa, out = sys.argv[1:7]
base = f"https://github.com/{repo}"
icon = "https://github.com/khcrysalis/Feather/blob/v1.x/iOS/Resources/Icons/Main/Mac@3x.png?raw=true"
date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
download = f"{base}/releases/download/{tag}/Feather.ipa"
size = os.path.getsize(ipa)

source = {
    "name": "Feather (multi-profile fork)",
    "identifier": f"io.github.{repo.replace('/', '.').lower()}.feather-source",
    "subtitle": "Feather with per-extension profiles and automatic updates.",
    "website": base,
    "iconURL": icon,
    "tintColor": "848ef9",
    "apps": [
        {
            "name": "Feather",
            "bundleIdentifier": "thewonderofyou.Feather",
            "developerName": repo.split("/")[0],
            "subtitle": "On-device signing, with extension profiles.",
            "localizedDescription": "This fork's Feather: signs app extensions with their own "
                                    "provisioning profiles and can sign updates automatically.",
            "iconURL": icon,
            "tintColor": "848ef9",
            "versions": [
                {
                    "version": version,
                    "buildVersion": build,
                    "date": date,
                    "size": size,
                    "downloadURL": download,
                }
            ],
            # Older AltStore-style fields, as in upstream's app-repo.json.
            "version": version,
            "versionDate": date,
            "size": size,
            "downloadURL": download,
            "appPermissions": {},
        }
    ],
    "news": [],
}
with open(out, "w") as f:
    json.dump(source, f, indent=2)
print(f"Wrote {out} for {version} ({tag})")
