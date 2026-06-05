# lazy_word

`lazy_word` is a local-first Flutter flashcard app for learning vocabulary from downloaded Anki `.apkg` decks.

The app imports an APKG file on-device, parses the Anki collection and media locally, stores cards and review progress in SQLite, and provides two swipe-based study flows:

- Read-through mode for moving through a deck and marking unknown cards.
- Unknown review mode for weighted practice until difficult cards are known consistently.

There are no accounts, backend services, sync, analytics, telemetry, or network features. Deck data, media, and progress stay on the device.

## Tech

- Flutter desktop/mobile app
- Local SQLite storage with `sqflite` and `sqflite_common_ffi`
- APKG archive parsing with local media extraction
- HTML card rendering with `flutter_html`
- Local audio playback, including `ffplay` on Linux

## Development

```bash
flutter pub get
flutter analyze --no-pub
flutter test
flutter build linux --no-pub
```

## License

MIT
