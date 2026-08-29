# Battery Indicator

A macOS menu-bar battery app with a launchd-managed helper daemon.

## Run locally

```sh
make run
```

This builds and opens `BatteryIndicator.app`. On first launch, the app registers its embedded helper with `SMAppService` and opens **System Settings → General → Login Items & Extensions** if approval is required. Enable Battery Indicator there; the running app detects the approval and connects automatically.

You can also open `BatteryIndicator.xcodeproj` and run the shared `BatteryIndicator` scheme. The scheme builds both targets; launchd starts the helper when the app opens its privileged XPC connection.

## Project structure

- `BatteryIndicator`: menu-bar application target.
- `BatteryHelper`: embedded command-line helper target.
- `BatteryCore`, `BatteryData`, `BatteryXPC`, and `BatteryUI`: shared local Swift package modules.
- `Configuration/com.mathias.BatteryIndicator.helper.plist`: embedded LaunchDaemon definition.

Debug builds use Xcode's local ad-hoc signing. Before distribution, select an Apple Development team for both targets and strengthen the XPC signing requirements in `BatteryHelperService` to include that team identifier.
