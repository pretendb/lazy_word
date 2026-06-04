# Milestone: Rich Flashcard Experience v2

You are upgrading an existing Flutter vocabulary-learning application.

The current application already supports:

* Importing local `.apkg` files
* Parsing Anki notes/cards
* SQLite storage
* Read-through mode
* Unknown-word review mode
* Weighted random review scheduling

The current implementation is too simplistic because it discards most of the educational content already contained inside the APKG file.

The objective of this milestone is to transform the app from a simple flashcard viewer into a rich offline Anki deck player.

---

# High-Level Goals

Improve the learning experience by supporting:

1. Rich HTML rendering
2. Images
3. Audio pronunciation
4. Example sentences
5. Cloze/fill-in-the-blank cards
6. Modern card presentation
7. Hidden internal IDs
8. Better card metadata handling

The application must remain:

* Fully offline
* No backend
* No network access
* No cloud sync

---

# Existing Limitation

Current importer:

* strips HTML
* removes `[sound:xxx]`
* ignores images
* ignores media
* assumes only front/back plain text

This behavior must be replaced.

---

# APKG Media Support

APKG packages contain:

* collection.anki2
* media mapping file
* image files
* audio files

Implement media extraction during import.

Import flow:

1. Extract APKG archive.
2. Parse media mapping file.
3. Copy all media assets into app-private storage.
4. Create local references to those assets.
5. Persist media information in SQLite.

Add a media table:

```sql
CREATE TABLE media (
    id TEXT PRIMARY KEY,
    card_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    local_path TEXT NOT NULL,
    media_type TEXT NOT NULL
);
```

Supported media types:

```text
image
audio
```

Future types may be added later.

---

# Preserve HTML

Do not strip HTML anymore.

Store:

```text
front_html
back_html
```

instead of only cleaned text.

Update card schema:

```sql
ALTER TABLE cards ADD COLUMN front_html TEXT;
ALTER TABLE cards ADD COLUMN back_html TEXT;
```

If schema migration is difficult, recreate the table.

---

# HTML Rendering

Add Flutter support for rendering rich HTML.

Recommended package:

flutter_html

Requirements:

* render bold text
* render italic text
* render colors
* render lists
* render simple tables
* render embedded image tags

Do not support remote URLs.

Only local content is allowed.

---

# Audio Pronunciation

Many decks contain:

[sound:filename.mp3]

Do not remove these tags.

Parse them.

Create:

```dart
class AudioAttachment {
    final String filename;
    final String localPath;
}
```

Card UI should display:

🔊 Play Pronunciation

Requirements:

* play local files only
* support multiple audio attachments
* stop previous audio when new audio starts
* handle missing files gracefully

Recommended package:

just_audio

---

# Image Support

Many decks contain:

<img src="apple.jpg">

Resolve image references using extracted media files.

Display images directly inside cards.

Requirements:

* preserve aspect ratio
* lazy load
* support large images
* support multiple images per card
* gracefully handle missing files

Use local file paths only.

No network loading.

---

# Card Model Upgrade

Current model is too simple.

Replace with:

```dart
enum CardType {
    basic,
    image,
    audio,
    cloze,
    mixed
}
```

```dart
class FlashCard {
    String id;

    String frontHtml;
    String backHtml;

    List<ImageAttachment> images;
    List<AudioAttachment> audio;

    CardType type;
}
```

Detect card type automatically.

Examples:

Basic:

* text only

Image:

* contains image assets

Audio:

* contains audio assets

Mixed:

* contains both

Cloze:

* contains cloze markup

---

# Cloze Card Support

Support Anki cloze syntax.

Examples:

{{c1::apple}}

or

{{c1::apple::hint}}

When detected:

CardType = cloze

Rendering rules:

Front side:

The fruit is _____.

Back side:

The fruit is apple.

User interaction:

1. Think of answer.
2. Tap "Show Answer".
3. Swipe up = knew it.
4. Swipe down = did not know it.

Do not reveal answers automatically.

---

# Card UI Redesign

Current card UI is visually poor.

Design a modern mobile learning experience.

Requirements:

* large typography
* proper spacing
* card elevation/shadow
* smooth card flip animation
* responsive layout
* dark mode support
* image-first layout when images exist

Preferred structure:

Image

Word

IPA pronunciation

Audio button

Example sentence

Meaning

Additional notes

Card should feel closer to Quizlet or Duolingo quality.

---

# Hide Internal IDs

Users should never see:

* database IDs
* Anki note IDs
* card IDs

Remove all ID displays from production UI.

IDs remain internal only.

If debugging is needed:

```dart
const bool debugShowIds = false;
```

Only show IDs when enabled.

---

# Read-Through Mode Upgrade

Current read-through mode:

front
back

Upgrade to:

rich card rendering

Support:

* HTML
* images
* audio
* examples

User still swipes:

↑ known

↓ add to unknown list

---

# Unknown Review Mode Upgrade

Unknown review mode should use the same rich card renderer.

Do not create a second card UI implementation.

Reuse the same component.

Requirements:

* one card renderer
* multiple review modes

---

# Reusable Components

Create reusable widgets:

```text
RichFlashCardWidget
AudioPlayerButton
ImageAttachmentView
ClozeCardView
CardFlipView
```

Avoid duplicate rendering logic.

---

# Error Handling

Handle:

* missing media
* corrupt media mapping
* unsupported media formats
* invalid HTML
* invalid cloze syntax

The app must never crash.

Fallback gracefully.

---

# Future TODOs

Add TODO markers for:

* video support
* field mapping UI
* advanced Anki templates
* deck browser
* multiple imported decks
* spaced repetition algorithm
* media caching optimization

---

# Success Criteria

A high-quality vocabulary deck containing:

* HTML formatting
* images
* audio pronunciation
* example sentences
* cloze deletions

should import successfully and display correctly.

The resulting experience should feel like a polished mobile vocabulary-learning application rather than a plain text card viewer.

