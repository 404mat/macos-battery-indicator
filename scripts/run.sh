#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h}"
helper_label="com.mathias.BatteryIndicator.helper"
open_app=true

if [[ "${1:-}" == "--build-only" ]]; then
    open_app=false
    shift
fi

derived_data_path="${DERIVED_DATA_PATH:-${project_directory}/.build/XcodeDerivedData}"
app_path="${derived_data_path}/Build/Products/Debug/BatteryIndicator.app"

team_id="${1:-${DEVELOPMENT_TEAM:-}}"
identity_name=""

if [[ -z "${team_id}" ]]; then
    identity_name="$(${SECURITY_BIN:-/usr/bin/security} find-identity -v -p codesigning \
        | /usr/bin/awk -F'"' '/"Apple Development:/ { print $2; exit }')"

    if [[ -z "${identity_name}" ]]; then
        print -u2 "No Apple Development signing identity was found in the keychain."
        print -u2 "Add your Apple ID in Xcode, or pass a team ID: $0 TEAM_ID"
        exit 1
    fi

    certificate_subject="$(${SECURITY_BIN:-/usr/bin/security} find-certificate -c "${identity_name}" -p \
        | /usr/bin/openssl x509 -noout -subject -nameopt RFC2253)"
    team_id="$(print -r -- "${certificate_subject}" \
        | /usr/bin/awk -F',' '{ for (i = 1; i <= NF; i++) if ($i ~ /^OU=/) { sub(/^OU=/, "", $i); print $i; exit } }')"

    if [[ -z "${team_id}" ]]; then
        print -u2 "Could not extract the development team ID from ${identity_name}."
        print -u2 "Pass it explicitly instead: $0 TEAM_ID"
        exit 1
    fi
else
    identity_name="Apple Development"
fi

print "Signing with team ${team_id} (${identity_name})"

helper_registration=""
if ! helper_registration="$(/bin/launchctl print "system/${helper_label}" 2>&1)"; then
    helper_registration=""
fi

# Do not overwrite executables while the signed app or helper is running.
/usr/bin/killall BatteryIndicator 2>/dev/null || true
if [[ "${helper_registration}" == *"state = running"* ]]; then
    print "Stopping the installed battery helper (administrator access required)…"
    /usr/bin/sudo /bin/launchctl kill SIGKILL "system/${helper_label}"
fi

cd "${project_directory}"
/usr/bin/xcodebuild \
    -project BatteryIndicator.xcodeproj \
    -scheme BatteryIndicator \
    -configuration Debug \
    -derivedDataPath "${derived_data_path}" \
    -quiet \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="${identity_name}" \
    DEVELOPMENT_TEAM="${team_id}" \
    build

# Xcode injects development entitlements into command-line targets even when
# they do not request capabilities. Re-sign the standalone daemon without
# those entitlements, then reseal the containing app bundle.
/usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp=none \
    --sign "${identity_name}" \
    "${app_path}/Contents/MacOS/BatteryHelper"
/usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp=none \
    --sign "${identity_name}" \
    "${app_path}"

if ${open_app}; then
    /usr/bin/open "${app_path}"
else
    print "Built ${app_path}"
fi
