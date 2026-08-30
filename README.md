# Battery Indicator

A macOS menu-bar battery app with a launchd-managed helper daemon.

## Run locally

```sh
make run
```

This finds an Apple Development identity in your keychain, extracts its team ID, then builds and opens `BatteryIndicator.app`. The local build omits Xcode's injectable debug entitlements because a standalone daemon cannot embed the provisioning profile those entitlements require. If more than one development team is available, select one explicitly with `./scripts/run.sh TEAM_ID`.

Battery monitoring and history run inside the app and require no privileged helper. The optional helper is reserved for charge-control operations. Install, approve, or unregister it explicitly from **Settings → Charge Control**; the app never registers it at launch.

You can also open `BatteryIndicator.xcodeproj` and run the shared `BatteryIndicator` scheme. The scheme builds both targets; launchd starts the helper when the app opens its privileged XPC connection.

## Project structure

- `BatteryIndicator`: menu-bar application target.
- `BatteryHelper`: embedded command-line helper target.
- `BatteryCore`, `BatteryData`, `BatteryXPC`, and `BatteryUI`: shared local Swift package modules.
- `Configuration/com.mathias.BatteryIndicator.helper.plist`: embedded LaunchDaemon definition.

Local builds use the first Apple Development identity found in the keychain. Before distribution, strengthen the XPC signing requirements in `BatteryHelperService` to include that team identifier.
