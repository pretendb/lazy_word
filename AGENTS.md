# AGENTS.md

## Project Overview

This repository contains a Flutter MVP for a pure-local flashcard vocabulary app.

The app imports a downloaded Anki `.apkg` file, parses it locally, converts it into flashcards, and provides two swipe-based learning modes:

1. Read-through mode
   - Swipe up: the user knows the word.
   - Swipe down: the user does not know the word; add it to the unknown-word list.

2. Unknown review mode
   - Uses weighted random sampling from the unknown-word list.
   - Swipe up: the user knows the word once.
   - Three consecutive swipe-up reviews remove the word from the unknown-word list.
   - Swipe down: the user does not know the word; reset known streak and increase future selection probability.

The app must be fully local. Do not add backend, cloud sync, analytics, account login, telemetry, or network calls.

---

## Core Product Rules

- First launch:
  - If no deck has been imported, show the import screen.
  - The user must select a local `.apkg` file.

- Later launches:
  - If a deck has already been imported, open the home screen directly.
  - Do not ask the user to select the `.apkg` file again.

- Replacing deck:
  - The user may tap `Choose New .apkg`.
  - Show a confirmation dialog.
  - Replacing the deck clears the old deck, old cards, old unknown list, and old progress.

- MVP limitations:
  - Ignore Anki audio and images.
  - Strip HTML instead of rendering full HTML.
  - Treat the first note field as the card front.
  - Treat the second note field as the card back.
  - Add TODO comments for field mapping, media extraction, cloze support, and HTML rendering.

---

## Required Dependencies

Use these packages unless there is a strong reason not to:

```yaml
file_picker
path_provider
sqflite
path
archive
crypto
```

Do not add heavy state-management or UI libraries unless the task explicitly requires them.

Preferred MVP state management:
- `ChangeNotifier`, `ValueNotifier`, or simple controller classes.

Avoid:
- unnecessary networking packages
- Firebase
- cloud storage SDKs
- analytics SDKs
- overly complex architecture frameworks

---

## Expected Project Structure

Prefer this structure:

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

    settings/
      settings_screen.dart
```

Keep files small and focused.

---

## Database Schema

Use local SQLite through `sqflite`.

Create these tables:

```sql
CREATE TABLE decks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  source_file_name TEXT NOT NULL,
  imported_at INTEGER NOT NULL,
  card_count INTEGER NOT NULL
);

CREATE TABLE cards (
  id TEXT PRIMARY KEY,
  deck_id TEXT NOT NULL,
  anki_note_id TEXT,
  anki_card_id TEXT,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  raw_fields TEXT,
  read_seen_count INTEGER NOT NULL DEFAULT 0,
  last_read_at INTEGER,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE
);

CREATE TABLE unknown_cards (
  card_id TEXT PRIMARY KEY,
  deck_id TEXT NOT NULL,
  known_streak INTEGER NOT NULL DEFAULT 0,
  failure_count INTEGER NOT NULL DEFAULT 0,
  review_weight REAL NOT NULL DEFAULT 1.0,
  added_at INTEGER NOT NULL,
  last_reviewed_at INTEGER,
  FOREIGN KEY(card_id) REFERENCES cards(id) ON DELETE CASCADE,
  FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE
);

CREATE TABLE review_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id TEXT NOT NULL,
  deck_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
```

Use transactions and batch inserts for deck import.

---

## APKG Import Rules

Implement an importer similar to:

```dart
class ApkgImporter {
  Future<ImportResult> importFromFile(File file);
}
```

The importer must:

1. Validate that the selected file has the `.apkg` extension.
2. Copy the file into app-private or temporary storage.
3. Decode the `.apkg` file as a zip archive.
4. Extract `collection.anki2`.
5. Open `collection.anki2` as SQLite.
6. Read Anki notes/cards.
7. Parse note fields.
8. For MVP:
   - `front = first note field`
   - `back = second note field`
9. Clean text:
   - Strip HTML tags.
   - Remove `[sound:xxx]` tags.
   - Trim whitespace.
   - Skip cards with empty front or empty back.
10. Generate stable local card IDs using a hash of:
   - deck id
   - Anki note id
   - Anki card id
   - front text
   - back text
11. Save the deck and cards into the app database.

Important:
- `.apkg` is not plain text.
- It is a package/archive containing Anki database files.
- Do not attempt to parse it with string scanning alone.
- Keep parsing code isolated in `import/`.

---

## Startup Behavior

On app start:

```text
if currentDeckId exists and the deck exists in SQLite:
    show HomeScreen
else:
    show ImportDeckScreen
```

Persist the current deck id locally.

Use app-private storage for copied/imported files.

---

## Screen Requirements

### ImportDeckScreen

Must include:

- Button: `Choose .apkg File`
- Import progress text
- Error state
- Success transition to HomeScreen

Import progress examples:

```text
Selecting file...
Copying file...
Extracting package...
Reading Anki database...
Generating cards...
Saving local database...
Import complete.
```

### HomeScreen

Must include:

- Current deck name
- Total card count
- Unknown word count
- Button: `Read-through Mode`
- Button: `Unknown Review Mode`
- Button: `Choose New .apkg`

### ReadThroughScreen

Behavior:

- Show one card at a time.
- Swipe up:
  - Increment `read_seen_count`.
  - Update `last_read_at`.
  - Log review event:
    - `mode = read_through`
    - `action = known`
- Swipe down:
  - Increment `read_seen_count`.
  - Update `last_read_at`.
  - Insert into `unknown_cards` if not already present.
  - Log review event:
    - `mode = read_through`
    - `action = unknown`

UI text should clearly explain:

```text
Read-through Mode
Swipe up = known
Swipe down = add to unknown list
```

### UnknownReviewScreen

Behavior:

- Only use cards in `unknown_cards`.
- Pick cards using weighted random sampling.
- Swipe up:
  - `known_streak += 1`
  - If `known_streak >= 3`, delete the card from `unknown_cards`.
  - Otherwise reduce `review_weight` mildly, but never below `1.0`.
  - Log review event:
    - `mode = unknown_review`
    - `action = known`
- Swipe down:
  - `known_streak = 0`
  - `failure_count += 1`
  - `review_weight = min(review_weight + 2, 20)`
  - Update `last_reviewed_at`
  - Log review event:
    - `mode = unknown_review`
    - `action = unknown`

UI text should clearly explain:

```text
Unknown Review Mode
Swipe up = known once
Three consecutive known reviews remove the word
Swipe down = still unknown, appears more often
```

---

## Weighted Random Scheduler

Implement this in `domain/review_scheduler.dart`.

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
- Swipe up decreases weight mildly only if the word remains in the unknown list.
- Three consecutive swipe-up reviews remove the word.

---

## Error Handling

Handle these cases clearly:

- No file selected.
- Selected file is not `.apkg`.
- `.apkg` cannot be decoded as zip.
- `collection.anki2` not found.
- SQLite open/read fails.
- No valid cards found.
- Imported deck has empty front/back fields.
- Database write fails.

Do not crash the app for malformed decks. Show a useful error message.

---

## UX Requirements

Keep UI simple and clean.

Required empty states:

- No deck imported.
- Import failed.
- No valid cards found.
- Read-through completed.
- Unknown list is empty.

Add undo support if feasible:

- Keep the last swipe action in memory.
- Provide an `Undo` button.
- Undo should restore the previous card state as much as possible.

Do not overbuild animations. Swipe behavior and correctness are more important than visual polish.

---

## Code Style

- Use clear names.
- Keep business logic out of widgets where practical.
- Put database logic in DAO classes.
- Put APKG parsing logic in importer/parser classes.
- Put review-card selection logic in `ReviewScheduler`.
- Prefer small methods with explicit error handling.
- Use comments for non-obvious Anki parsing logic.
- Add TODO comments for known MVP limitations.

---

## Testing Expectations

When possible, add tests for:

- HTML stripping.
- `[sound:xxx]` removal.
- note field parsing.
- weighted random scheduler boundaries.
- unknown-card known-streak logic.
- unknown-card failure logic.
- card ID hash stability.

Manual test checklist:

1. Fresh install opens ImportDeckScreen.
2. User can select `.apkg`.
3. Valid cards are imported.
4. Second app launch opens HomeScreen directly.
5. Read-through swipe up records known event.
6. Read-through swipe down adds card to unknown list.
7. Unknown review swipe up increments known streak.
8. Three consecutive swipe-up reviews remove the card from unknown list.
9. Unknown review swipe down resets streak and increases weight.
10. Choose New `.apkg` replaces the old deck after confirmation.

---

## Do Not Do

- Do not add network features.
- Do not add login.
- Do not add cloud sync.
- Do not add Firebase.
- Do not add analytics.
- Do not delete source code unrelated to the task.
- Do not silently change the data model without updating this file.
- Do not implement a full Anki clone.
- Do not attempt complete Anki media/cloze/template support in the MVP.

---

## Implementation Priority

Build in this order:

1. Flutter app skeleton and navigation.
2. SQLite database and DAO layer.
3. Import screen and file picker.
4. APKG unzip and `collection.anki2` extraction.
5. Basic Anki note/card parsing.
6. Save imported cards to local SQLite.
7. Startup persistence.
8. Home screen statistics.
9. Read-through swipe mode.
10. Unknown review weighted mode.
11. Error states and replacement-deck flow.
12. Undo and tests.

Correct local data behavior is more important than visual polish.
