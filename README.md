# Out Loud

Out Loud is a World of Warcraft: Forever addon in development for reading quest
text aloud with configurable NPC voices.

## Overview

The goal is automatic quest narration that chooses a character's voice from the
speaking NPC's visual model family and runtime gender. A Blizzard-style Talking
Head presentation is intended to show the speaker and dialogue while speech is
generated and played.

The voice configuration, voice resolver, Talking Head UI, and speech controller
are implemented as separate components. Automatic quest narration is not yet
connected to them.

## Current Features

- Options UI with saved Male and Female voice assignments for each Voice Family.
- Generated mappings from NPC model FileDataIDs to Voice Families.
- A runtime voice resolver that combines the model family with `UnitSex(unit)`
  and returns the configured voice.
- A custom Talking Head UI with an NPC portrait, name, dialogue text, faction
  styling, close button, and a controllable loading spinner.
- A speech controller that accepts supplied text and a WoW TTS voice ID,
  supports sentence streaming and whole-text speech, and can cancel narration.
- A saved reading-mode setting used by the speech dispatcher.

## How Voice Selection Works

The resolver reads two independent properties of the NPC:

```text
NPC visual model -> Model FileDataID -> Voice Family
NPC UnitSex      -> Male / Female
```

It combines the family and gender to choose the player's configured voice.
Gender comes from the live NPC, rather than the model mapping.

Multiple model IDs can share one Voice Family and the same voice configuration.
For example, the two Skyborne model IDs in the Forever mapping both use
`SKYBORNE`, with separate Male and Female voice choices.

## Voice Configuration

The Out Loud Options page provides one row with separate Male and Female voice
selectors for every available Voice Family. Selectors list the TTS voices
available to the game and include a **Not set** option.

Available families come from generated mapping data. Each unique family appears
once, regardless of how many models use it. Assignments are saved between sessions.

## Speech Modes

The **Reading** section of Options offers two modes:

- **Split text:** reads sentence by sentence, submitting the first sentence
  immediately and prefetching one sentence ahead as playback begins.
- **Read full text** (default): sends the complete text to TTS in one request.

The speech dispatcher uses this choice whenever a caller supplies text and a
voice. Automatic quest-triggered speech is still to be integrated.

## Project Status

The mappings, saved voice configuration, voice resolver, Talking Head UI, and
TTS controller are implemented as separate components. Automatic quest
narration and its UI integration are still in development.

Still to integrate:

- Automatic quest-dialog detection and quest-text extraction.
- Connecting quest text and the speaking NPC to voice resolution and speech.
- Connecting Talking Head visibility and loading/playback state to narration.

## Architecture

The addon separates voice resolution, speech, and presentation:

- Generated Voice Family mappings connect NPC visual models to configurable families.
- `VoiceSelection` combines those mappings with `UnitSex` gender detection to
  resolve a configured voice.
- The TTS controller speaks supplied text with a supplied voice and applies the
  selected speech mode.
- Talking Head provides the speaker portrait, dialogue display, and loading state.
- Quest integration will supply the NPC and text and connect these components.

## Development

Implementation details, testing commands, and in-game diagnostic helpers are
documented in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
