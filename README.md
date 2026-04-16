# MD Buddy

An iPad app for live stage use. Displays the song/section structure of an Ableton Live set in real time, lets performers jump to any section with a tap, and controls transport (play/stop) — all from the stage.

## Requirements

- iPad with iOS 17.0+
- Xcode 15+ (for building)
- [AbletonTracksApp bridge](../AbletonTracksApp) running on the Mac running Ableton Live
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (to regenerate the Xcode project if needed)

## Build

```bash
cd MD Buddy
xcodegen generate   # only needed if project.yml changed
open MD Buddy.xcodeproj
```

Build and run on your iPad from Xcode. The app connects to the bridge automatically via Bonjour when the iPad is plugged in via USB, or over WiFi otherwise.

If auto-discovery fails after 3 seconds, it falls back to the manually configured IP address in Settings (gear icon, top right).

## Usage

1. Start the bridge on the Mac (`bash start.sh` in AbletonTracksApp, or it starts automatically at login if installed as a service)
2. Open the Ableton set with `== Song Name ==` markers
3. Launch MD Buddy on the iPad — it connects automatically
4. Tap any section button to jump there; PLAY/STOP controls transport

## Connection

The app discovers the bridge via Bonjour service type `_stagepad._tcp.`. When the iPad is plugged in via USB, the connection routes over USB for lower latency. Over WiFi it still works but with slightly higher latency.

Manual IP fallback: tap the gear icon → enter the Mac's IP address.

## Song/section structure

Songs and sections are read from Ableton cue point markers. See the [bridge README](../AbletonTracksApp/README.md) for the naming convention.

Section buttons are colour-coded and icon-decorated by section type (Verse, Chorus, Bridge, etc.) automatically.
