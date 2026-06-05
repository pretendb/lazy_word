# Agents.md

## Project Overview

This repository contains `lazy_word`, a Flutter desktop/mobile MVP for a fully local flashcard vocabulary app.

The app imports a downloaded Anki `.apkg` package, parses it locally, stores flashcards and progress in local SQLite, and provides two swipe-based learning modes:

1. Read-through mode
   - Swipe up: user knows the card.
   - Swipe down: user does not know the card; add it to the unknown list.

2. Unknown review mode
   - Uses weighted random sampling from `unknown_cards`.
   - Swipe up: increment `known_streak`; three consecutive known reviews remove the card from `unknown_cards`.
   - Swipe down: reset `known_streak`, increment `failure_count`, and increase `review_weight`.

The app must remain local-only. Do not add backend services, sync, accounts, analytics, telemetry, or network features.

---

## Current Implementation

The app is implemented in Flutter using simple controllers and `ChangeNotifier`.

Current important dependencies:

```yaml
archive
crypto
file_picker
flutter_html
just_audio
path
path_provider
sqflite
sqflite_common_ffi
```

Dependency notes:

- `sqflite` is used for mobile-style SQLite APIs.
- `sqflite_common_ffi` is required for Linux/Windows desktop SQLite.
- `flutter_html` renders Anki template HTML.
- `just_audio` is kept for non-Linux platforms.
- Linux audio playback intentionally uses local `ffplay` through `Process.start`, not `just_audio`, because `just_audio` has no default Linux implementation and the `media_kit`/MPV backend produced noisy cache warnings in this environment.
- Do not re-add `just_audio_media_kit` or `media_kit_libs_linux` unless you also solve MPV disk-cache warnings.

---

## Project Structure

```text
lib/
  main.dart
  app.dart

  core/
    app_paths.dart
    errors.dart
    result.dart

  data/
    local_db.dart
    deck_dao.dart
    card_dao.dart
    media_dao.dart
    unknown_card_dao.dart
    review_event_dao.dart

  import/
    apkg_importer.dart
    anki_parser.dart
    html_cleaner.dart

  domain/
    deck.dart
    flash_card.dart
    unknown_card.dart
    review_event.dart
    review_scheduler.dart

  features/
    import_deck/
      import_deck_screen.dart
      import_deck_controller.dart

    home/
      home_screen.dart

    read_through/
      read_through_screen.dart
      read_through_controller.dart
      swipe_card_view.dart

    unknown_review/
      unknown_review_screen.dart
      unknown_review_controller.dart
```

There is no separate settings screen currently; deck replacement is available from `HomeScreen` through `Choose New .apkg`.

---

## Local Data Model

SQLite is initialized in `lib/data/local_db.dart`.

Current schema version is `2`.

Tables:

- `decks`
- `cards`
- `media`
- `unknown_cards`
- `review_events`

Important `cards` columns:

- `front` / `back`: cleaned text used for search, IDs, and fallback display.
- `front_html` / `back_html`: rendered Anki template HTML used by the flashcard view.
- `card_type`: one of `basic`, `image`, `audio`, `cloze`, `mixed`.
- `raw_fields`: original Anki fields joined by Anki's unit separator.

Important `media` columns:

- `card_id`
- `file_name`
- `local_path`
- `media_type`: `image` or `audio`

Deck replacement must clear the old deck, cards, media, unknown list, and review events.

---

## APKG Import Rules

`ApkgImporter.importFromFile(File file)` owns package-level import.

Importer behavior:

1. Validate `.apkg` extension.
2. Copy the selected package to temporary app storage.
3. Decode it as a zip archive.
4. Extract the Anki media manifest and referenced media files into app-private deck media storage.
5. Prefer `collection.anki21`, then fall back to `collection.anki2`.
6. Try each collection database until valid cards are produced.
7. Save deck, cards, and media rows in a transaction/batch.
8. Persist the imported deck ID as the current deck.

Important: modern APKG files can include an empty compatibility `collection.anki2` and store the real notes/cards in `collection.anki21`. Do not regress this behavior.

---

## Anki Parsing Rules

`AnkiParser` reads Anki SQLite databases and renders card templates.

Current supported behavior:

- Reads `col.models`, `notes`, and `cards`.
- Maps note fields by model field names.
- Renders `qfmt` and `afmt`.
- Handles `{{FrontSide}}` by not duplicating the rendered front in `back_html`.
- Handles basic conditional sections.
- Handles basic cloze syntax.
- Preserves HTML for display.
- Cleans text with `HtmlCleaner` for `front` and `back`.
- Extracts image references from `<img src="...">`.
- Extracts audio references from `[sound:...]`.
- Maps media references to app-private local media paths.
- Generates stable card IDs from deck ID, Anki note ID, Anki card ID, front text, and back text.

Known limitations:

- This is not a full Anki clone.
- Complex Anki filters/templates may not render perfectly.
- Media is extracted only when referenced through standard Anki media manifest entries and simple HTML/audio tags.
- Keep parser improvements isolated in `lib/import/`.

---

## Startup Behavior

On app start:

```text
if currentDeckId exists and the deck exists in SQLite:
    show HomeScreen
else:
    show ImportDeckScreen
```

Current deck persistence is implemented in `AppPaths`.

---

## Flashcard UI

`SwipeCardView` displays one compact card.

Current behavior:

- Content is merged into one compact card body.
- The card avoids a scrollbar by using `FittedBox.scaleDown`.
- If `back_html` already includes the front content, the separate front display is suppressed.
- Images are constrained relative to available card height.
- Audio buttons are compact.
- Vertical drag is used for swipe actions:
  - up = known
  - down = unknown

Linux audio behavior:

- `SwipeCardView` uses `ffplay -nodisp -autoexit -loglevel quiet <file>` on Linux.
- `ffplay` must be available in the runtime environment for Linux audio playback.
- Non-Linux platforms use `just_audio`.

---

## Screen Requirements

### ImportDeckScreen

Must include:

- `Choose .apkg File`
- Import progress text
- Error state
- Success transition to `HomeScreen`

### HomeScreen

Must include:

- Current deck name
- Source file name
- Total card count
- Unknown word count
- `Read-through Mode`
- `Unknown Review Mode`
- `Choose New .apkg`

Replacing a deck must show confirmation and then clear the old deck/progress.

### ReadThroughScreen

Swipe up:

- Increment `read_seen_count`.
- Update `last_read_at`.
- Log review event with `mode = read_through`, `action = known`.

Swipe down:

- Increment `read_seen_count`.
- Update `last_read_at`.
- Insert into `unknown_cards` if not already present.
- Log review event with `mode = read_through`, `action = unknown`.

### UnknownReviewScreen

Card selection:

- Use `ReviewScheduler` weighted random sampling.

Swipe up:

- `known_streak += 1`
- If `known_streak >= 3`, delete from `unknown_cards`.
- Otherwise reduce `review_weight` mildly, but never below `1.0`.
- Log review event with `mode = unknown_review`, `action = known`.

Swipe down:

- `known_streak = 0`
- `failure_count += 1`
- `review_weight = min(review_weight + 2, 20)`
- Update `last_reviewed_at`.
- Log review event with `mode = unknown_review`, `action = unknown`.

---

## Weighted Random Scheduler

Implemented in `lib/domain/review_scheduler.dart`.

Algorithm:

```text
totalWeight = sum(reviewWeight)
r = random value in [0, totalWeight)
cumulative = 0

for each card:
    cumulative += card.reviewWeight
    if cumulative >= r:
        return card
```

Rules:

- Minimum review weight: `1.0`
- Maximum review weight: `20.0`
- Swipe down increases weight.
- Swipe up decreases weight only if the card remains in the unknown list.

---

## Linux Runner Notes

`linux/runner/main.cc` includes a targeted workaround for a noisy GTK/GDK cursor-theme message:

```text
Unable to load ... from the cursor theme
```

The runner sets `XCURSOR_THEME=Adwaita` when no cursor theme is defined and filters that exact message path. Avoid broad suppression of GTK/GDK logs.

---

## App Packaging

Linux Debian packaging is currently a manual local build process.

Package naming:

- Debian package name: `lazy-word`
- Installed app directory: `/opt/lazy-word`
- Launcher command: `lazy-word`
- GTK application ID: `com.example.lazy_word`
- Desktop entry: `/usr/share/applications/com.example.lazy_word.desktop`
- Desktop icon name: `lazy-word`
- Debian artifact path: `dist/lazy-word_<version>_amd64.deb`

Use the Flutter app version from `pubspec.yaml` without the build suffix. For example, `version: 1.0.0+1` becomes Debian package version `1.0.0`.

Before packaging, build and verify:

```bash
flutter pub get
flutter analyze --no-pub
flutter test
flutter build linux --no-pub --release
```

The release bundle to package is:

```text
build/linux/x64/release/bundle/
```

Create the Debian staging tree:

```bash
mkdir -p dist/deb/lazy-word/DEBIAN
mkdir -p dist/deb/lazy-word/opt/lazy-word
mkdir -p dist/deb/lazy-word/usr/bin
mkdir -p dist/deb/lazy-word/usr/share/applications
mkdir -p dist/deb/lazy-word/usr/share/icons/hicolor/256x256/apps
cp -a build/linux/x64/release/bundle/. dist/deb/lazy-word/opt/lazy-word/
```

`dist/deb/lazy-word/DEBIAN/control` must include `ffmpeg`, because Linux audio playback uses `ffplay`:

```text
Package: lazy-word
Version: 1.0.0
Section: education
Priority: optional
Architecture: amd64
Maintainer: chzw517 <chzw517@outlook.com>
Depends: libgtk-3-0, libblkid1, liblzma5, ffmpeg
Description: Local-first Flutter flashcard app for Anki APKG decks
 lazy_word imports downloaded Anki .apkg decks locally, stores cards and
 review progress in SQLite, and supports swipe-based vocabulary review.
```

Create the launcher script at `dist/deb/lazy-word/usr/bin/lazy-word`:

```sh
#!/bin/sh
exec /opt/lazy-word/lazy_word "$@"
```

Create the desktop entry at `dist/deb/lazy-word/usr/share/applications/com.example.lazy_word.desktop`.
The desktop file basename must match the GTK application ID so Linux shells can associate the running window with the installed launcher and taskbar icon:

```ini
[Desktop Entry]
Name=lazy_word
Comment=Local flashcard vocabulary app
Exec=lazy-word
Icon=lazy-word
Terminal=false
Type=Application
Categories=Education;
StartupWMClass=com.example.lazy_word
```

Copy the package icon:

```bash
cp linux/runner/resources/lazy-word-256.png \
  dist/deb/lazy-word/usr/share/icons/hicolor/256x256/apps/lazy-word.png
```

Add `DEBIAN/postinst` and `DEBIAN/postrm` scripts to refresh desktop and icon caches when available:

```sh
#!/bin/sh
set -e

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi

exit 0
```

Normalize permissions before building:

```bash
find dist/deb/lazy-word -type d -exec chmod 755 {} +
find dist/deb/lazy-word -type f -exec chmod 644 {} +
chmod 755 dist/deb/lazy-word/usr/bin/lazy-word
chmod 755 dist/deb/lazy-word/DEBIAN/postinst
chmod 755 dist/deb/lazy-word/DEBIAN/postrm
chmod 755 dist/deb/lazy-word/opt/lazy-word/lazy_word
chmod 755 dist/deb/lazy-word/opt/lazy-word/lib/*.so
```

Build the `.deb` with root ownership in the archive:

```bash
dpkg-deb --root-owner-group --build \
  dist/deb/lazy-word \
  dist/lazy-word_1.0.0_amd64.deb
```

Verify package metadata and contents:

```bash
dpkg-deb --field dist/lazy-word_1.0.0_amd64.deb Package Version Architecture Depends
dpkg-deb --contents dist/lazy-word_1.0.0_amd64.deb
```

Manual install/uninstall smoke test:

```bash
sudo dpkg -i ./dist/lazy-word_1.0.0_amd64.deb
sudo apt-get install -f
lazy-word
sudo apt remove lazy-word
```

Use `dpkg -i` for local install tests. In this environment, `sudo apt install ./dist/lazy-word_1.0.0_amd64.deb` can report `Unsupported file ... given on commandline` even when the `.deb` is valid.

Do not commit generated `dist/` package output unless explicitly requested.

---

## Error Handling

Handle these clearly:

- No file selected.
- Selected file is not `.apkg`.
- APKG cannot be decoded as zip.
- No supported collection database found.
- Collection SQLite open/read fails.
- No valid cards found.
- Media extraction failures where possible.
- Database write failures.
- Missing audio files.
- Linux `ffplay` playback failure.

Do not crash the app for malformed decks. Show a useful error message.

---

## Code Style

- Keep the app local-only.
- Keep business logic out of widgets where practical.
- Put database logic in DAO classes.
- Put APKG/archive work in `apkg_importer.dart`.
- Put Anki database/template parsing in `anki_parser.dart`.
- Put review-card selection logic in `ReviewScheduler`.
- Prefer small methods with explicit error handling.
- Do not add heavy state management unless the task clearly requires it.
- Do not silently change schema behavior without updating this file.

---

## Testing And Verification

Existing tests cover:

- HTML stripping and sound-tag removal.
- Card ID stability.
- Anki template rendering/media mapping.
- APKG collection ordering (`collection.anki21` before `collection.anki2`).
- Weighted random scheduler boundaries.

Before handing off meaningful changes, run:

```bash
flutter analyze --no-pub
flutter test
flutter build linux --no-pub
```

If dependencies changed, run `flutter pub get` first and then use the same checks.

Manual test checklist:

1. Fresh install opens `ImportDeckScreen`.
2. User can select a local `.apkg`.
3. Modern APKG files with `collection.anki21` import valid cards.
4. Imported media displays/plays locally.
5. Second app launch opens `HomeScreen`.
6. Read-through swipe up records a known event.
7. Read-through swipe down adds card to unknown list.
8. Unknown review swipe up increments known streak.
9. Three consecutive known reviews remove the card from unknown list.
10. Unknown review swipe down resets streak and increases weight.
11. `Choose New .apkg` replaces the old deck after confirmation.

---

## Do Not Do

- Do not add network features.
- Do not add login.
- Do not add cloud sync.
- Do not add Firebase.
- Do not add analytics or telemetry.
- Do not delete unrelated source code.
- Do not implement a full Anki clone.
- Do not reintroduce MPV/media_kit for Linux audio unless the cache-warning issue is solved.
