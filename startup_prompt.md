You are implementing a Flutter MVP for a pure-local flashcard vocabulary app. The app has no network functionality.

Goal:
Build a Flutter app that imports a local Anki `.apkg` file, parses it into local flashcards, saves them into a local SQLite database, and provides two swipe-based learning modes.

Important constraints:

* No backend.
* No network calls.
* All data must stay local.
* On first launch, the user must select a downloaded `.apkg` file from the file system.
* On later launches, the app must use the previously imported deck automatically.
* The user can tap “Choose New .apkg” to replace the current deck.
* Replacing the deck should clear old cards and old progress after confirmation.

Use these Flutter/Dart packages unless there is a strong reason not to:

* file_picker
* path_provider
* sqflite
* path
* archive
* crypto

App screens:

1. ImportDeckScreen

   * Shown when no deck has been imported.
   * Lets the user select a `.apkg` file.
   * Shows import progress and errors.
2. HomeScreen

   * Shows current deck name and statistics.
   * Buttons:

     * Read-through Mode
     * Unknown Review Mode
     * Choose New .apkg
3. ReadThroughScreen

   * Shows cards from the imported deck.
   * Swipe up = user knows the word.
   * Swipe down = user does not know the word; add it to the unknown list.
4. UnknownReviewScreen

   * Shows only cards from the unknown list.
   * Cards are selected using weighted random sampling.
   * Swipe up = user knows it once. Increase knownStreak by 1.
   * If knownStreak reaches 3 consecutive known swipes, remove the card from the unknown list.
   * Swipe down = user does not know it. Reset knownStreak to 0, increase failureCount, and increase reviewWeight so the card appears more often.
5. Settings or simple menu area

   * Allows “Choose New .apkg”.

Architecture:
Use a simple layered structure:

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

```
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

Data model:
Create a local SQLite database with these tables:

decks:

* id TEXT PRIMARY KEY
* name TEXT NOT NULL
* source_file_name TEXT NOT NULL
* imported_at INTEGER NOT NULL
* card_count INTEGER NOT NULL

cards:

* id TEXT PRIMARY KEY
* deck_id TEXT NOT NULL
* anki_note_id TEXT
* anki_card_id TEXT
* front TEXT NOT NULL
* back TEXT NOT NULL
* raw_fields TEXT
* read_seen_count INTEGER NOT NULL DEFAULT 0
* last_read_at INTEGER
* created_at INTEGER NOT NULL

unknown_cards:

* card_id TEXT PRIMARY KEY
* deck_id TEXT NOT NULL
* known_streak INTEGER NOT NULL DEFAULT 0
* failure_count INTEGER NOT NULL DEFAULT 0
* review_weight REAL NOT NULL DEFAULT 1.0
* added_at INTEGER NOT NULL
* last_reviewed_at INTEGER

review_events:

* id INTEGER PRIMARY KEY AUTOINCREMENT
* card_id TEXT NOT NULL
* deck_id TEXT NOT NULL
* mode TEXT NOT NULL
* action TEXT NOT NULL
* created_at INTEGER NOT NULL

APKG importer:
Implement ApkgImporter.importFromFile(File file).

Expected flow:

1. Validate file extension is `.apkg`.
2. Copy file into app-private storage or temporary storage.
3. Decode it as a zip archive.
4. Extract `collection.anki2`.
5. Open `collection.anki2` as SQLite.
6. Read Anki notes/cards.
7. Parse note fields.
8. For MVP:

   * front = first note field
   * back = second note field
9. Clean text:

   * Strip HTML tags.
   * Remove `[sound:xxx]` tags.
   * Trim whitespace.
   * Skip cards with empty front or empty back.
10. Generate stable local card IDs using a hash of deck id, Anki note id, Anki card id, and front/back text.
11. Save deck and cards into the app database using transactions/batches.

Important:
Anki `.apkg` files are zip archives containing a SQLite database. Do not parse `.apkg` as plain text.

Startup behavior:

* On app start, check whether a current deck exists.
* If no deck exists, show ImportDeckScreen.
* If a deck exists, show HomeScreen.
* Persist currentDeckId locally.

Swipe logic:
Read-through mode:

* Swipe up:

  * Increment read_seen_count.
  * Update last_read_at.
  * Log review event with mode = "read_through", action = "known".
* Swipe down:

  * Increment read_seen_count.
  * Update last_read_at.
  * Insert into unknown_cards if not already present.
  * Log review event with mode = "read_through", action = "unknown".

Unknown review mode:

* Use weighted random card selection from unknown_cards.
* Swipe up:

  * known_streak += 1.
  * If known_streak >= 3, delete the row from unknown_cards.
  * Otherwise, mildly reduce review_weight but keep it >= 1.
  * Log review event with mode = "unknown_review", action = "known".
* Swipe down:

  * known_streak = 0.
  * failure_count += 1.
  * review_weight = min(review_weight + 2, 20).
  * Update last_reviewed_at.
  * Log review event with mode = "unknown_review", action = "unknown".

Weighted random algorithm:

* totalWeight = sum(reviewWeight)
* Generate random value r in [0, totalWeight)
* Iterate through cards, accumulating weights
* Return the first card where cumulativeWeight >= r

UX requirements:

* Show clear mode labels.
* Show an empty state when all read-through cards are completed.
* Show an empty state when the unknown list is empty.
* Add a confirmation dialog before replacing the current deck.
* Add a simple Undo button for the last swipe action if feasible.
* Keep UI simple and clean.

Deliverables:

1. Working Flutter project structure.
2. SQLite database initialization and DAO classes.
3. APKG import pipeline.
4. Read-through swipe screen.
5. Unknown review swipe screen.
6. Basic error handling.
7. Clear comments around APKG parsing limitations.

MVP limitations are acceptable:

* Ignore Anki audio/images/media for now.
* Strip HTML instead of rendering full HTML.
* Assume the first field is front and the second field is back.
* Add TODO comments for future field mapping, media extraction, cloze cards, and HTML rendering.

