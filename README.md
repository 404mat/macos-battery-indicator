# Battery Indicator

A macOS 27 menu-bar battery app.

## Run locally

```sh
make run
```

This finds an Apple Development identity in your keychain, extracts its team ID, then builds and opens `BatteryIndicator.app`. If more than one development team is available, select one explicitly with `./scripts/run.sh TEAM_ID`.

Charging limits are managed by macOS 27. Open **Settings → Charge Control** in the app to jump directly to the native Charging settings and choose a limit from 80% to 100%.

You can also open `BatteryIndicator.xcodeproj` and run the shared `BatteryIndicator` scheme.

## Project structure

- `BatteryIndicator`: menu-bar application target.
- `BatteryCore`, `BatteryData`, and `BatteryUI`: shared local Swift package modules.
