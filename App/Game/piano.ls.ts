import { CATALOG, Lesson } from "./catalog.ls";

@external("la", "getSpriteByName")
declare function getSpriteByName(ptr: usize, len: i32): u32;
@external("la", "setX")
declare function setX(handle: u32, value: f32): void;
@external("la", "setY")
declare function setY(handle: u32, value: f32): void;
@external("la", "setScale")
declare function setScale(handle: u32, x: f32, y: f32): void;
@external("la", "setAlpha")
declare function setAlpha(handle: u32, value: f32): void;
@external("la", "setVisible")
declare function setVisible(handle: u32, value: i32): void;
@external("la", "setFill")
declare function setFill(handle: u32, rgba: u32): void;
@external("la", "setText")
declare function setText(handle: u32, ptr: usize, len: i32): void;
@external("la", "getText")
declare function getText(handle: u32, ptr: usize, capacity: i32): i32;
@external("la", "keyDown")
declare function keyDown(code: i32): i32;
@external("la", "pointerX")
declare function pointerX(): f32;
@external("la", "pointerY")
declare function pointerY(): f32;
@external("la", "pointerDown")
declare function pointerDown(): i32;
@external("la", "playSoundEx")
declare function playSoundEx(ptr: usize, len: i32, gain: f32, loop: i32, pitch: f32, pan: f32, fade: f32): void;
@external("la", "updateSound")
declare function updateSound(ptr: usize, len: i32, gain: f32, pitch: f32, pan: f32, fade: f32): void;
@external("la", "stopSound")
declare function stopSound(ptr: usize, len: i32): void;

const FIRST: i32 = 48;
const KEY_COUNT: i32 = 42;
const KEY_X: f32 = 32;
const KEY_Y: f32 = 604;
const KEY_STEP: f32 = 61.44;
const WHITE_PITCHES: i32[] = [0, 2, 4, 5, 7, 9, 11];
const WHITE_POSITIONS: i32[] = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6];
const STAFF_POSITIONS: i32[] = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
const KEY_CODES: i32[] = [65, 87, 83, 69, 68, 70, 84, 71, 89, 72, 85, 74, 75, 79, 76, 80, 186];
const SHORTCUTS: string[] = ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J", "K", "O", "L", "P", ";"];
const NAMES: string[] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
const COLORS: u32[] = [0x76B94DFF, 0x669A42FF, 0x29A780FF, 0x219879FF, 0xEEAC18FF, 0x8963E8FF,
  0x7954CCFF, 0x478FECFF, 0x3F7CCAFF, 0xEB6D91FF, 0xD35D7FFF, 0x677CE0FF];
const LIBRARY_PAGE_SIZE: i32 = 4;
const CATEGORY_NAMES: string[] = ["All lessons", "Exercises", "Folk & favorites", "Classical & ragtime", "Custom import"];
const CUSTOM_IMPORT_LIMIT: i32 = 8192;

let melody: i32[] = [];
let fingers: i32[] = [];
let lengths: f32[] = [];
let starts: f32[] = [];
let guide: i32[] = [];
let guideFingers: i32[] = [];
let totalBeats: f32 = 0;
let measureBeats: f32 = 1.5;
let lesson: i32 = 0;
let libraryCategory: i32 = 0;
let libraryPage: i32 = 0;
let libraryMatches: i32[] = [];
let customLesson: i32 = -1;
let index: i32 = 0;
let tempo: i32 = 84;
let mode: i32 = 0;
let view: i32 = 0;
let score: i32 = 0;
let hits: i32 = 0;
let attempts: i32 = 0;
let streak: i32 = 0;
let playing: bool = true;
let completed: bool = false;
let looping: bool = false;
let metronome: bool = false;
let labels: bool = true;
let hands: bool = true;
let instructions: bool = true;
let handPanel: bool = false;
let volume: f32 = 0.7;
let instrument: i32 = 0;
let elapsed: f32 = 0;
let visualIndex: f32 = 0;
let currentHit: bool = false;
let demoStarted: bool = false;
let lastBeat: i32 = -1;
let overlay: i32 = 0;
let resumeAfterModal: bool = true;
let pointerNote: i32 = -1;
let suppressClick: i32 = -1;
let spaceHeld: bool = false;
let escapeHeld: bool = false;
let feedbackFrames: i32 = 0;
let flashNote: i32 = -1;
let flashFrames: i32 = 0;
let clock: i32 = 0;
let previousSecond: i32 = -1;
let keyHeld: Int32Array = new Int32Array(KEY_COUNT);
let keyTint: Array<u32> = new Array<u32>(KEY_COUNT);
let keyLabel: Array<u32> = new Array<u32>(KEY_COUNT);
let keyFinger: Array<u32> = new Array<u32>(KEY_COUNT);
let keyShortcut: Array<u32> = new Array<u32>(KEY_COUNT);
let noteRoot: Array<u32> = new Array<u32>(8);
let noteBody: Array<u32> = new Array<u32>(8);
let noteText: Array<u32> = new Array<u32>(8);
let noteHead: Array<u32> = new Array<u32>(8);
let noteSharp: Array<u32> = new Array<u32>(8);
let noteLedger: Array<u32> = new Array<u32>(8);
let shown: Int32Array = new Int32Array(8);
let mini: Array<u32> = new Array<u32>(32);
let importSource: string = "";
let importCursor: i32 = 0;
let importOk: bool = true;
const importBuffer: Uint8Array = new Uint8Array(CUSTOM_IMPORT_LIMIT);

export function __la_abi_version(): i32 { return 22; }

function node(id: string): u32 {
  const bytes = String.UTF8.encode(id);
  return getSpriteByName(changetype<usize>(bytes), bytes.byteLength);
}

function text(id: string, value: string): void { write(node(id), value); }
function write(handle: u32, value: string): void {
  const bytes = String.UTF8.encode(value);
  setText(handle, changetype<usize>(bytes), bytes.byteLength);
}
function visible(id: string, value: bool): void { setVisible(node(id), value ? 1 : 0); }
function readWidget(id: string): string {
  const length = getText(node(id), importBuffer.dataStart, importBuffer.length);
  return length <= 0 ? "" : String.UTF8.decodeUnsafe(importBuffer.dataStart, length);
}
function black(note: i32): bool {
  const pc = note % 12;
  return pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10;
}
function keyX(note: i32): f32 {
  return KEY_X + <f32>(((note - FIRST) / 12) * 7 + WHITE_POSITIONS[note % 12]) * KEY_STEP
    - (black(note) ? 19 : 0);
}
function noteName(note: i32): string { return NAMES[note % 12] + (note / 12 - 1).toString(); }
function shortcut(note: i32): string { return note >= 60 && note <= 76 ? SHORTCUTS[note - 60] : "click"; }
function multiplier(): i32 { return min(5, 1 + streak / 4); }
function accuracy(): i32 { return attempts == 0 ? 0 : <i32>Math.round(<f64>hits * 100 / <f64>attempts); }
function timeLabel(beats: f32): string {
  const seconds = <i32>(beats * 60 / <f32>tempo);
  return (seconds / 60).toString().padStart(2, "0") + ":" + (seconds % 60).toString().padStart(2, "0");
}
function stopAll(): void {
  const bytes = String.UTF8.encode("");
  stopSound(changetype<usize>(bytes), bytes.byteLength);
}
function soundId(note: i32): string {
  if (instrument < 3) return (instrument == 0 ? "p" : instrument == 1 ? "o" : "s") + note.toString();
  const hit = note % 12 == 0 ? "k" : note % 12 == 2 ? "s" : "h";
  return (instrument == 3 ? "d" : "e") + hit;
}
function sound(note: i32): void {
  const bytes = String.UTF8.encode(soundId(note));
  stopSound(changetype<usize>(bytes), bytes.byteLength);
  playSoundEx(changetype<usize>(bytes), bytes.byteLength, volume, 0,
    instrument < 3 ? <f32>Math.pow(2, <f64>(note - 69) / 12) : 1, 0, 0.003);
}
function release(note: i32): void {
  const bytes = String.UTF8.encode(soundId(note));
  updateSound(changetype<usize>(bytes), bytes.byteLength, 0,
    instrument < 3 ? <f32>Math.pow(2, <f64>(note - 69) / 12) : 1, 0, 0.16);
}

function loadLesson(choice: i32): void {
  if (choice < 0 || choice >= CATALOG.length) {
    text("library-notice", "That lesson is not available. Choose another title.");
    return;
  }
  const selected = CATALOG[choice];
  if (selected.notes.length == 0) {
    text("library-notice", "This lesson has no playable notes. Choose another title.");
    return;
  }
  lesson = choice;
  melody = selected.notes;
  fingers = selected.fingers;
  lengths = selected.beats;
  guide = selected.guide;
  guideFingers = selected.guideFingers;
  measureBeats = <f32>selected.numerator * 4 / <f32>selected.denominator;
  tempo = selected.tempo;
  starts = new Array<f32>(melody.length);
  totalBeats = 0;
  for (let i = 0; i < melody.length; i++) {
    starts[i] = totalBeats;
    totalBeats += lengths[i];
  }
  text("song-title", selected.title);
  text("song-author", selected.author);
  text("difficulty", selected.level == 1 ? "Beginner / Lv. 1" : selected.level == 2 ? "Beginner / Lv. 2" : "Intermediate");
  text("key-signature", selected.keySignature);
  text("time-top", selected.numerator.toString());
  text("time-bottom", selected.denominator.toString());
  const previewCount: i32 = min(32, melody.length);
  for (let i = 0; i < 32; i++) {
    setVisible(mini[i], i < previewCount ? 1 : 0);
    if (i < previewCount) {
      const noteIndex = previewCount == 1 ? 0 : i * (melody.length - 1) / (previewCount - 1);
      setX(mini[i], 421 + starts[noteIndex] / totalBeats * 590);
      setY(mini[i], max(<f32>838, min(<f32>866, 842 + (76 - <f32>melody[noteIndex]) * 1.15)));
      setFill(mini[i], COLORS[melody[noteIndex] % 12]);
    }
  }
  for (let i = 0; i < 8; i++) shown[i] = -99;
  reset();
  drawNotes();
}

function reset(): void {
  stopAll();
  index = 0; score = 0; hits = 0; attempts = 0; streak = 0;
  completed = false; playing = true; elapsed = 0; visualIndex = 0;
  currentHit = false; demoStarted = false; lastBeat = -1; previousSecond = -1;
  feedbackFrames = 0; flashFrames = 0; overlay = 0;
  visible("modal", false);
  refresh();
}

function hint(): void {
  if (mode == 3) {
    text("feedback", "Play anything you like. Every key is yours.");
    text("hint-note", "FREE");
  } else if (completed) {
    text("feedback", "Beautiful work. Your next chapter is waiting.");
    text("hint-note", "OK");
  } else {
    const note = melody[index];
    text("hint-note", noteName(note));
    setFill(node("hint-note-bg"), COLORS[note % 12]);
    text("feedback", !playing ? (mode == 2 ? "Demo paused. Press play to keep listening."
      : "Practice paused. Explore the keys, or press play.")
      : mode == 2 ? "Demo: " + noteName(note) + "  /  finger " + fingers[index].toString() + ". Follow the key."
      : "Play " + noteName(note) + " with finger " + fingers[index].toString() + "  /  key " + shortcut(note));
  }
  text("coach", mode == 0 ? "No rush. The music waits for you."
    : mode == 1 ? "Stay with the beat. Every note is a fresh start."
    : mode == 2 ? "Watch the keys. Stop demo when you're ready to try."
    : "Explore melodies, chords, and rhythms at your own pace.");
}

function refresh(): void {
  text("tempo", tempo.toString() + " BPM");
  text("instrument-label", instrument == 0 ? "GRAND PIANO  ›" : instrument == 1 ? "ORGAN  ›"
    : instrument == 2 ? "SYNTH  ›" : instrument == 3 ? "DRUM KIT  ›" : "808 DRUMS  ›");
  text("score", score.toString());
  text("canvas-score", score.toString());
  text("streak", multiplier().toString() + "x STREAK");
  text("canvas-streak", multiplier().toString() + "x");
  text("accuracy", attempts == 0 ? "--" : accuracy().toString() + "%");
  text("note-count", (completed ? melody.length : index + 1).toString() + " / " + melody.length.toString() + " notes");
  text("mode-label", mode == 0 ? "Wait for me" : mode == 1 ? "Play along" : mode == 2 ? "Listen" : "Free play");
  text("practice-state", mode == 3 ? "FREE PLAY" : completed ? "LESSON COMPLETE"
    : !playing ? "TAKE A BREATH" : mode == 2 ? "LISTEN & LEARN" : "YOUR TURN TO PLAY");
  visible("pause-icon", playing);
  visible("play-icon", !playing);
  visible("demo-control", mode != 2 || completed);
  visible("stop-demo-control", mode == 2 && !completed);
  setFill(node("loop-face"), looping ? 0x334C43FF : 0x192333FF);
  setFill(node("loop-icon"), looping ? 0x7BD5A8FF : 0x9DAABCFF);
  setScale(node("streak-fill"), <f32>max(1, streak % 4) / 4, 1);
  setAlpha(node("streak-fill"), streak > 0 ? 1 : 0.18);
  for (let i = 0; i < 3; i++) {
    setFill(node("star" + i.toString()), hits >= (i + 1) * melody.length / 3 ? 0xEAAE37FF : 0xD5DEEAFF);
  }
  hint();
  updateKeys();
  updateTime();
}

function updateTime(): void {
  const beat = completed ? totalBeats : starts[index] + elapsed;
  const measures = <i32>Math.ceil(totalBeats / measureBeats);
  text("measure", "MEASURE " + min(measures, <i32>(beat / measureBeats) + 1).toString()
    + " / " + measures.toString());
  text("time", timeLabel(beat) + " / " + timeLabel(totalBeats));
  setScale(node("mini-progress"), max(<f32>0.003, beat / totalBeats), 1);
  setX(node("mini-cursor"), 417 + min(<f32>1, beat / totalBeats) * 600);
  text("progress-label", (<i32>(beat / totalBeats * 100)).toString() + "% COMPLETE");
}

function updateKeys(): void {
  for (let i = 0; i < KEY_COUNT; i++) {
    const note = FIRST + i;
    const finger = guide.indexOf(note);
    const guideFinger = finger >= 0 ? guideFingers[finger] : 0;
    const active = keyHeld[i] != 0 || (flashFrames > 0 && flashNote == note)
      || (mode == 2 && playing && demoStarted && !completed && melody[index] == note);
    const expected = mode != 3 && !completed && melody[index] == note;
    const guided = playing && expected;
    const colored = active || guided;
    const labelColor: u32 = colored ? 0xFFFFFFFF : black(note) ? 0xB9C4D3FF : 0x718096FF;
    setFill(keyTint[i], COLORS[note % 12]);
    setAlpha(keyTint[i], active ? 1 : guided ? 0.92 : 0);
    setFill(keyLabel[i], labelColor);
    setFill(keyFinger[i], labelColor);
    setFill(keyShortcut[i], colored ? 0xFFFFFFCC : black(note) ? 0x90A0B3FF : 0xA0ABB9FF);
    setVisible(keyLabel[i], labels ? 1 : 0);
    setVisible(keyShortcut[i], labels ? 1 : 0);
    write(keyFinger[i], mode == 3 ? "" : expected && hands ? fingers[index].toString()
      : hands && finger >= 0 ? guideFinger.toString() : "");
  }
  text("hand-current", completed ? "Nicely played!" : noteName(melody[index]) + "  /  Finger " + fingers[index].toString());
  for (let i = 0; i < 5; i++) {
    setAlpha(node("finger" + (i + 1).toString()), !completed && fingers[index] == i + 1 ? 1 : 0.3);
  }
}

function next(): void {
  if (index + 1 == melody.length) {
    if (looping) { reset(); return; }
    completed = true; playing = false;
    text("result-title", mode == 2 ? "Now, make it yours." : "A little better. Every note.");
    text("result-detail", mode == 2 ? "You've heard the melody. Try it in Wait for me mode."
      : "You played " + hits.toString() + " of " + melody.length.toString() + " notes.");
    text("result-score", score.toString());
    text("result-accuracy", attempts == 0 ? "--" : accuracy().toString() + "%");
    showOverlay(4);
  } else {
    index++;
    elapsed = 0; currentHit = false; demoStarted = false;
  }
  refresh();
}

function press(note: i32): void {
  if (overlay != 0) return;
  sound(note);
  flashNote = note; flashFrames = 12;
  if (!playing || completed || mode == 2 || mode == 3 || currentHit) { updateKeys(); return; }
  attempts++;
  if (note == melody[index]) {
    hits++; streak++; score += 100 * multiplier();
    currentHit = true;
    if (mode == 0) next();
    else refresh();
    if (!completed) {
      text("feedback", mode == 1 ? "Lovely! Stay with the beat."
        : "Lovely!  Next: " + noteName(melody[index]) + "  /  finger " + fingers[index].toString());
      feedbackFrames = 30;
    }
  } else {
    streak = 0;
    refresh();
    text("feedback", "Almost. Find " + noteName(melody[index]) + "  /  key " + shortcut(melody[index]));
    feedbackFrames = 75;
  }
  updateKeys();
}

function pointerPitch(): i32 {
  const x = pointerX(), y = pointerY();
  if (x < KEY_X || x >= KEY_X + 25 * KEY_STEP || y < KEY_Y || y > KEY_Y + 194) return -1;
  if (y < KEY_Y + 126) {
    for (let note = FIRST; note < FIRST + KEY_COUNT; note++) {
      if (black(note) && x >= keyX(note) && x < keyX(note) + 38) return note;
    }
  }
  const white = <i32>((x - KEY_X) / KEY_STEP);
  return FIRST + (white / 7) * 12 + WHITE_PITCHES[white % 7];
}

export function pointerPress(): void {
  if (overlay != 0) return;
  pointerNote = pointerPitch();
  if (pointerNote < 0) return;
  suppressClick = pointerNote;
  if (keyHeld[pointerNote - FIRST] == 0) press(pointerNote);
  keyHeld[pointerNote - FIRST] = 1;
  updateKeys();
}

function activate(note: i32): void {
  if (suppressClick == note) { suppressClick = -1; return; }
  press(note);
}

function drawNotes(): void {
  const base = <i32>Math.floor(visualIndex) - 1;
  const fraction = visualIndex - <f32>max(0, base + 1);
  const visualBeat = starts[max(0, base + 1)] + fraction * lengths[max(0, base + 1)];
  for (let i = 0; i < 8; i++) {
    const absolute = base + i;
    if (absolute < 0 || absolute >= melody.length) { setVisible(noteRoot[i], 0); continue; }
    const note = melody[absolute];
    if (shown[i] != absolute) {
      shown[i] = absolute;
      setFill(noteBody[i], COLORS[note % 12]);
      write(noteText[i], NAMES[note % 12]);
    }
    const staffStep = (note / 12 - 5) * 7 + STAFF_POSITIONS[note % 12];
    let x: f32 = 368 + (<f32>absolute - visualIndex) * 176;
    let y: f32 = 424 - <f32>staffStep * 12 - 17;
    let inBounds = x >= 164 && x < 1538;
    if (view == 1) {
      const height: f32 = max(<f32>34, lengths[absolute] * 82);
      x = keyX(note) + 4;
      y = 528 - (starts[absolute] - visualBeat) * 115 - height;
      setScale(noteBody[i], black(note) ? 0.19 : 0.32, height / 34);
      inBounds = y >= 220 && y < 532;
    } else setScale(noteBody[i], 1, 1);
    setX(noteRoot[i], x); setY(noteRoot[i], y);
    setVisible(noteRoot[i], inBounds ? 1 : 0);
    setAlpha(noteRoot[i], absolute < index ? 0.25 : absolute == index ? 1 : 0.83);
    setVisible(noteBody[i], view == 2 ? 0 : 1);
    setVisible(noteText[i], view == 2 ? 0 : 1);
    setVisible(noteHead[i], view == 2 ? 1 : 0);
    setVisible(noteSharp[i], view == 2 && black(note) ? 1 : 0);
    setVisible(noteLedger[i], view == 2 && note < 62 ? 1 : 0);
  }
}

function setView(value: i32): void {
  view = value;
  visible("staff", view != 1);
  visible("staff-cursor", view != 1);
  visible("waterfall-lanes", view == 1);
  setX(node("tab-active"), view == 0 ? 466 : view == 1 ? 639 : 801);
  text("view-description", view == 0 ? "SHEET + FLOW" : view == 1 ? "FOLLOW THE FALLING NOTES" : "READ THE MELODY");
  drawNotes();
}
export function sheetFlow(): void { setView(0); }
export function waterfall(): void { setView(1); }
export function sheetOnly(): void { setView(2); }
export function tempoDown(): void { tempo = max(40, tempo - 4); refresh(); }
export function tempoUp(): void { tempo = min(160, tempo + 4); refresh(); }
export function toggleLoop(): void { looping = !looping; refresh(); }
export function cycleMode(): void {
  mode = (mode + 1) % 4;
  elapsed = 0; demoStarted = false; lastBeat = -1;
  if (mode == 0 && currentHit && !completed) next();
  stopAll(); refresh();
}
export function togglePlay(): void {
  if (completed) { reset(); return; }
  playing = !playing;
  if (!playing) stopAll();
  demoStarted = false;
  refresh();
}
export function restart(): void { reset(); }
export function startDemo(): void { mode = 2; reset(); }
export function retryPractice(): void { mode = 0; reset(); }
export function seek(): void {
  if (overlay != 0) return;
  const position = max(<f32>0, min(<f32>0.999, (pointerX() - 417) / 600)) * totalBeats;
  let target: i32 = 0;
  for (let i = 0; i < melody.length; i++) if (starts[i] <= position) target = i;
  reset();
  index = target; visualIndex = <f32>target;
  refresh(); drawNotes();
}
function showOverlay(kind: i32): void {
  if (overlay == 0) resumeAfterModal = playing;
  overlay = kind; playing = false;
  if (kind != 4) stopAll();
  visible("modal", true);
  visible("library-panel", kind == 1);
  visible("settings-panel", kind == 2);
  visible("help-panel", kind == 3);
  visible("result-panel", kind == 4);
  refresh();
}
export function closeOverlay(): void {
  overlay = 0;
  playing = resumeAfterModal && !completed;
  demoStarted = false;
  visible("modal", false);
  refresh();
}
function renderLibrary(): void {
  visible("custom-import-panel", libraryCategory == 4);
  if (libraryCategory == 4) {
    libraryMatches = [];
    setY(node("library-category-active"), 337 + <f32>libraryCategory * 42);
    text("library-summary", "Custom import / paste a converter entry for this session only");
    text("library-notice", customLesson < 0 ? "Paste a TypeScript Lesson Entry and press Add temporary lesson."
      : "Your temporary lesson is ready in this session. Import again to replace it.");
    visible("library-page-label", false);
    visible("library-previous", false);
    visible("library-next", false);
    for (let row = 0; row < LIBRARY_PAGE_SIZE; row++) visible("library-row" + row.toString(), false);
    return;
  }
  visible("custom-import-panel", false);
  libraryMatches = [];
  for (let i = 0; i < CATALOG.length; i++) {
    if (CATALOG[i].notes.length > 0 && (libraryCategory == 0 || CATALOG[i].category == libraryCategory)) {
      libraryMatches.push(i);
    }
  }
  const pages: i32 = max(1, (libraryMatches.length + LIBRARY_PAGE_SIZE - 1) / LIBRARY_PAGE_SIZE);
  libraryPage = max(0, min(libraryPage, pages - 1));
  setY(node("library-category-active"), 337 + <f32>libraryCategory * 42);
  text("library-summary", CATEGORY_NAMES[libraryCategory] + " / " + libraryMatches.length.toString()
    + " playable excerpts");
  text("library-page-label", "Page " + (libraryPage + 1).toString() + " of " + pages.toString());
  visible("library-page-label", libraryMatches.length > 0);
  visible("library-previous", libraryPage > 0);
  visible("library-next", libraryPage + 1 < pages);
  text("library-notice", libraryMatches.length == 0 ? "No playable songs are available in this group."
    : "Choose a song, then practice or use Auto play.");
  for (let row = 0; row < LIBRARY_PAGE_SIZE; row++) {
    const prefix = "library-row" + row.toString();
    const position = libraryPage * LIBRARY_PAGE_SIZE + row;
    visible(prefix, position < libraryMatches.length);
    if (position >= libraryMatches.length) continue;
    const choice = libraryMatches[position];
    const item = CATALOG[choice];
    text(prefix + "/title", item.title);
    text(prefix + "/detail", item.author + " / " + item.notes.length.toString()
      + " notes / " + (item.level == 3 ? "Intermediate" : "Beginner"));
    setFill(node(prefix + "/accent"), choice == lesson ? 0x79A58DFF : 0x998ABDFF);
  }
}
function setLibraryCategory(category: i32): void {
  libraryCategory = category;
  libraryPage = 0;
  renderLibrary();
}
function importFail(message: string): void {
  importOk = false;
  text("custom-lesson-status", message);
}
function skipImportSpace(): void {
  while (importCursor < importSource.length && importSource.charCodeAt(importCursor) <= 32) importCursor++;
}
function acceptImport(char: i32): bool {
  skipImportSpace();
  if (importCursor < importSource.length && importSource.charCodeAt(importCursor) == char) {
    importCursor++;
    return true;
  }
  return false;
}
function requireImport(char: i32, message: string): void {
  if (!acceptImport(char)) importFail(message);
}
function parseQuoted(): string {
  if (!importOk) return "";
  skipImportSpace();
  if (importCursor >= importSource.length || importSource.charCodeAt(importCursor) != 34) {
    importFail("Expected a quoted text field from the converter.");
    return "";
  }
  importCursor++;
  let result = "";
  while (importCursor < importSource.length) {
    const code = importSource.charCodeAt(importCursor);
    if (code == 34) {
      importCursor++;
      return result;
    }
    if (code == 92 && importCursor + 1 < importSource.length) {
      importCursor++;
      result += importSource.charAt(importCursor);
    } else {
      result += importSource.charAt(importCursor);
    }
    importCursor++;
  }
  importFail("The pasted lesson has an unterminated quoted field.");
  return "";
}
function parseNumber(): f64 {
  if (!importOk) return 0;
  skipImportSpace();
  let sign: f64 = 1;
  if (importCursor < importSource.length) {
    const signCode = importSource.charCodeAt(importCursor);
    if (signCode == 45 || signCode == 43) {
      sign = signCode == 45 ? -1 : 1;
      importCursor++;
    }
  }
  let value: f64 = 0;
  let digits = 0;
  while (importCursor < importSource.length) {
    const code = importSource.charCodeAt(importCursor);
    if (code < 48 || code > 57) break;
    value = value * 10 + <f64>(code - 48);
    digits++;
    importCursor++;
  }
  if (importCursor < importSource.length && importSource.charCodeAt(importCursor) == 46) {
    importCursor++;
    let place: f64 = 0.1;
    while (importCursor < importSource.length) {
      const code = importSource.charCodeAt(importCursor);
      if (code < 48 || code > 57) break;
      value += <f64>(code - 48) * place;
      place *= 0.1;
      digits++;
      importCursor++;
    }
  }
  if (digits == 0) {
    importFail("Expected a number in the lesson entry.");
    return 0;
  }
  return sign * value;
}
function parseIntValue(): i32 { return <i32>Math.round(parseNumber()); }
function parseIntArray(): i32[] {
  const values: i32[] = [];
  requireImport(91, "Expected an array such as [60,62,64].");
  if (!importOk) return values;
  if (acceptImport(93)) return values;
  while (importOk) {
    values.push(parseIntValue());
    if (acceptImport(93)) return values;
    requireImport(44, "Expected commas between array values.");
  }
  return values;
}
function parseFloatArray(): f32[] {
  const values: f32[] = [];
  requireImport(91, "Expected a beat array such as [1,0.5,2].");
  if (!importOk) return values;
  if (acceptImport(93)) return values;
  while (importOk) {
    values.push(<f32>parseNumber());
    if (acceptImport(93)) return values;
    requireImport(44, "Expected commas between beat values.");
  }
  return values;
}
function validateCustomLesson(notes: i32[], fingers: i32[], beats: f32[],
  guideNotes: i32[], guideFingers: i32[], category: i32, level: i32, numerator: i32,
  denominator: i32, lessonTempo: i32): bool {
  if (notes.length == 0 || notes.length != fingers.length || notes.length != beats.length) {
    importFail("The lesson needs equal-length notes, fingers, and beats arrays.");
    return false;
  }
  if (category < 1 || category > 3 || level < 1 || level > 3) {
    importFail("Category and difficulty must be 1, 2, or 3.");
    return false;
  }
  if (lessonTempo < 40 || lessonTempo > 160 || numerator <= 0 || denominator <= 0 || guideNotes.length != guideFingers.length) {
    importFail("Tempo, meter, or guide-note data is outside the Virtuoso range.");
    return false;
  }
  for (let i = 0; i < notes.length; i++) {
    if (notes[i] < 48 || notes[i] > 89 || fingers[i] < 1 || fingers[i] > 5 || !isFinite(beats[i]) || beats[i] <= 0) {
      importFail("Notes must be C3-F6, fingers 1-5, and beats positive.");
      return false;
    }
  }
  for (let i = 0; i < guideNotes.length; i++) {
    if (guideNotes[i] < 48 || guideNotes[i] > 89 || guideFingers[i] < 1 || guideFingers[i] > 5) {
      importFail("Guide notes must use C3-F6 and fingers 1-5.");
      return false;
    }
  }
  return true;
}
export function importCustomLesson(): void {
  importSource = readWidget("custom-lesson-input");
  importOk = true;
  importCursor = importSource.indexOf("new Lesson(");
  if (importCursor < 0) {
    importFail("Paste the converter's TypeScript Lesson Entry: new Lesson(...).");
    return;
  }
  importCursor += 11;
  const title = parseQuoted(); requireImport(44, "Expected title, then author.");
  const author = parseQuoted(); requireImport(44, "Expected author, then category.");
  const category = parseIntValue(); requireImport(44, "Expected category, then difficulty.");
  const level = parseIntValue(); requireImport(44, "Expected difficulty, then key signature.");
  const keySignature = parseQuoted(); requireImport(44, "Expected key signature, then time numerator.");
  const numerator = parseIntValue(); requireImport(44, "Expected time numerator, then denominator.");
  const denominator = parseIntValue(); requireImport(44, "Expected time denominator, then tempo.");
  const lessonTempo = parseIntValue(); requireImport(44, "Expected tempo, then notes.");
  const notes = parseIntArray(); requireImport(44, "Expected notes, then fingers.");
  const lessonFingers = parseIntArray(); requireImport(44, "Expected fingers, then beats.");
  const beats = parseFloatArray(); requireImport(44, "Expected beats, then guide notes.");
  const guideNotes = parseIntArray(); requireImport(44, "Expected guide notes, then guide fingers.");
  const customGuideFingers = parseIntArray(); requireImport(44, "Expected guide fingers, then source.");
  const source = parseQuoted();
  if (!importOk || !validateCustomLesson(notes, lessonFingers, beats, guideNotes, customGuideFingers,
    category, level, numerator, denominator, lessonTempo)) return;
  const entry = new Lesson(title, author, category, level, keySignature, numerator, denominator, lessonTempo,
    notes, lessonFingers, beats, guideNotes, customGuideFingers, source);
  if (customLesson < 0) {
    CATALOG.push(entry);
    customLesson = CATALOG.length - 1;
  } else {
    CATALOG[customLesson] = entry;
  }
  text("custom-lesson-status", "Added temporary lesson: " + title + ". It will reset when you reload.");
  loadLesson(customLesson);
}
function pickLibraryRow(row: i32): void {
  if (overlay != 1) return;
  const position = libraryPage * LIBRARY_PAGE_SIZE + row;
  if (position < 0 || position >= libraryMatches.length) {
    text("library-notice", "No lesson is available in that row. Choose another group.");
    return;
  }
  loadLesson(libraryMatches[position]);
}
export function libraryAll(): void { setLibraryCategory(0); }
export function libraryExercises(): void { setLibraryCategory(1); }
export function libraryTraditional(): void { setLibraryCategory(2); }
export function libraryClassical(): void { setLibraryCategory(3); }
export function libraryCustom(): void { setLibraryCategory(4); }
export function __la_ext_action_libraryCustom(_h: u32): void { libraryCustom(); }
export function __la_ext_action_importCustomLesson(_h: u32): void { importCustomLesson(); }
export function libraryPrevious(): void { libraryPage--; renderLibrary(); }
export function libraryNext(): void { libraryPage++; renderLibrary(); }
export function libraryRowOne(): void { pickLibraryRow(0); }
export function libraryRowTwo(): void { pickLibraryRow(1); }
export function libraryRowThree(): void { pickLibraryRow(2); }
export function libraryRowFour(): void { pickLibraryRow(3); }
export function openLibrary(): void { renderLibrary(); showOverlay(1); }
export function openSettings(): void { showOverlay(2); }
export function openHelp(): void { showOverlay(3); }
export function lessonOne(): void { loadLesson(0); }
export function lessonTwo(): void { loadLesson(1); }
export function lessonThree(): void { loadLesson(2); }
export function toggleHands(): void {
  handPanel = !handPanel;
  visible("hand-panel", handPanel);
}
export function toggleFingerColors(): void { hands = !hands; settings(); updateKeys(); }
export function toggleLabels(): void { labels = !labels; settings(); updateKeys(); }
export function toggleMetronome(): void { metronome = !metronome; settings(); }
export function toggleInstructions(): void { instructions = !instructions; settings(); }
export function volumeDown(): void { volume = max(<f32>0, volume - 0.1); settings(); }
export function volumeUp(): void { volume = min(<f32>1, volume + 0.1); settings(); }
export function cycleInstrument(): void {
  stopAll();
  instrument = (instrument + 1) % 5;
  refresh();
}
function settings(): void {
  text("volume-label", (<i32>Math.round(volume * 100)).toString() + "%");
  text("metronome-label", metronome ? "On" : "Off");
  text("instructions-label", instructions ? "On" : "Off");
  text("labels-label", labels ? "On" : "Off");
  text("fingers-label", hands ? "On" : "Off");
  visible("guidance", instructions);
}

export function main(): void {
  for (let i = 0; i < KEY_COUNT; i++) {
    const prefix = "k" + (FIRST + i).toString() + "/";
    keyTint[i] = node(prefix + "tint"); keyLabel[i] = node(prefix + "name");
    keyFinger[i] = node(prefix + "finger"); keyShortcut[i] = node(prefix + "shortcut");
    const note = FIRST + i;
    write(keyLabel[i], note % 12 == 0 ? noteName(note) : NAMES[note % 12]);
    write(keyShortcut[i], note >= 60 && note <= 76 ? SHORTCUTS[note - 60] : "");
  }
  for (let i = 0; i < 8; i++) {
    const prefix = "note" + i.toString() + "/";
    noteRoot[i] = node("note" + i.toString()); noteBody[i] = node(prefix + "body");
    noteText[i] = node(prefix + "caption"); noteHead[i] = node(prefix + "notation");
    noteSharp[i] = node(prefix + "sharp"); noteLedger[i] = node(prefix + "ledger");
    shown[i] = -99;
  }
  for (let i = 0; i < 32; i++) mini[i] = node("mini" + i.toString());
  loadLesson(0); setView(0); settings();
}

export function onFrame(): void {
  clock++;
  const space = keyDown(32) != 0, escape = keyDown(27) != 0;
  if (escape && !escapeHeld && overlay != 0) closeOverlay();
  if (space && !spaceHeld && overlay == 0) togglePlay();
  spaceHeld = space; escapeHeld = escape;
  pointerNote = overlay == 0 && pointerDown() != 0 ? pointerPitch() : -1;
  let changed = false;
  for (let i = 0; i < KEY_COUNT; i++) {
    const note = FIRST + i;
    const down = pointerNote == note || (note >= 60 && note <= 76 && keyDown(KEY_CODES[note - 60]) != 0);
    if (overlay == 0 && down && keyHeld[i] == 0) {
      if (pointerNote == note) suppressClick = note;
      press(note); changed = true;
    }
    if (!down && keyHeld[i] != 0) { release(note); changed = true; }
    keyHeld[i] = down ? 1 : 0;
  }
  if (pointerDown() == 0) suppressClick = -1;
  if (feedbackFrames > 0 && --feedbackFrames == 0) hint();
  if (flashFrames > 0 && --flashFrames == 0) changed = true;
  if (changed) updateKeys();
  if (playing && overlay == 0 && (mode == 1 || mode == 2) && !completed) {
    if (mode == 2 && !demoStarted) {
      sound(melody[index]); demoStarted = true;
      updateKeys();
    }
    const beat = <i32>Math.floor(starts[index] + elapsed);
    if (metronome && beat != lastBeat) {
      const bytes = String.UTF8.encode("tick");
      playSoundEx(changetype<usize>(bytes), bytes.byteLength, volume * 0.35, 0, 1, 0, 0);
    }
    lastBeat = beat;
    elapsed += <f32>tempo / 3600;
    if (elapsed >= lengths[index]) {
      const remainder = elapsed - lengths[index];
      if (mode == 1 && !currentHit) { attempts++; streak = 0; }
      if (mode == 2) release(melody[index]);
      next();
      if (!completed && index != 0) elapsed = remainder;
    }
  }
  const target: f32 = <f32>index + ((mode == 1 || mode == 2) && !completed ? elapsed / lengths[index] : 0);
  visualIndex += (min(<f32>(melody.length - 1), target) - visualIndex) * 0.19;
  if (Math.abs(visualIndex - <f32>index) < 0.001 && (mode == 0 || mode == 3)) visualIndex = <f32>index;
  drawNotes();
  setAlpha(node("cursor-glow"), 0.13 + <f32>Math.sin(<f64>clock * 0.035) * 0.06);
  const second = <i32>((starts[index] + elapsed) * 60 / <f32>tempo);
  if (second != previousSecond) { previousSecond = second; updateTime(); }
}

export function getIndex(): i32 { return index; }
export function getExpected(): i32 { return melody[index]; }
export function getScore(): i32 { return score; }
export function getHits(): i32 { return hits; }
export function getAttempts(): i32 { return attempts; }
export function getTempo(): i32 { return tempo; }
export function getMode(): i32 { return mode; }
export function getView(): i32 { return view; }
export function getPlaying(): i32 { return playing ? 1 : 0; }
export function getCompleted(): i32 { return completed ? 1 : 0; }
export function getOverlay(): i32 { return overlay; }
export function getLength(): i32 { return melody.length; }
export function getVolume(): f32 { return volume; }
export function getElapsed(): f32 { return elapsed; }
export function getLesson(): i32 { return lesson; }
export function getCatalogLength(): i32 { return CATALOG.length; }
export function getCurrentFinger(): i32 { return fingers[index]; }
export function getCurrentDuration(): f32 { return lengths[index]; }
export function getTotalBeats(): f32 { return totalBeats; }
export function note48(): void { activate(48); }
export function note49(): void { activate(49); }
export function note50(): void { activate(50); }
export function note51(): void { activate(51); }
export function note52(): void { activate(52); }
export function note53(): void { activate(53); }
export function note54(): void { activate(54); }
export function note55(): void { activate(55); }
export function note56(): void { activate(56); }
export function note57(): void { activate(57); }
export function note58(): void { activate(58); }
export function note59(): void { activate(59); }
export function note60(): void { activate(60); }
export function note61(): void { activate(61); }
export function note62(): void { activate(62); }
export function note63(): void { activate(63); }
export function note64(): void { activate(64); }
export function note65(): void { activate(65); }
export function note66(): void { activate(66); }
export function note67(): void { activate(67); }
export function note68(): void { activate(68); }
export function note69(): void { activate(69); }
export function note70(): void { activate(70); }
export function note71(): void { activate(71); }
export function note72(): void { activate(72); }
export function note73(): void { activate(73); }
export function note74(): void { activate(74); }
export function note75(): void { activate(75); }
export function note76(): void { activate(76); }
export function note77(): void { activate(77); }
export function note78(): void { activate(78); }
export function note79(): void { activate(79); }
export function note80(): void { activate(80); }
export function note81(): void { activate(81); }
export function note82(): void { activate(82); }
export function note83(): void { activate(83); }
export function note84(): void { activate(84); }
export function note85(): void { activate(85); }
export function note86(): void { activate(86); }
export function note87(): void { activate(87); }
export function note88(): void { activate(88); }
export function note89(): void { activate(89); }

export function __la_ext_action_pointerPress(_target: u32): void { pointerPress(); }
export function __la_ext_action_sheetFlow(_target: u32): void { sheetFlow(); }
export function __la_ext_action_waterfall(_target: u32): void { waterfall(); }
export function __la_ext_action_sheetOnly(_target: u32): void { sheetOnly(); }
export function __la_ext_action_tempoDown(_target: u32): void { tempoDown(); }
export function __la_ext_action_tempoUp(_target: u32): void { tempoUp(); }
export function __la_ext_action_toggleLoop(_target: u32): void { toggleLoop(); }
export function __la_ext_action_cycleMode(_target: u32): void { cycleMode(); }
export function __la_ext_action_togglePlay(_target: u32): void { togglePlay(); }
export function __la_ext_action_restart(_target: u32): void { restart(); }
export function __la_ext_action_startDemo(_target: u32): void { startDemo(); }
export function __la_ext_action_retryPractice(_target: u32): void { retryPractice(); }
export function __la_ext_action_seek(_target: u32): void { seek(); }
export function __la_ext_action_closeOverlay(_target: u32): void { closeOverlay(); }
export function __la_ext_action_openLibrary(_target: u32): void { openLibrary(); }
export function __la_ext_action_libraryAll(_target: u32): void { libraryAll(); }
export function __la_ext_action_libraryExercises(_target: u32): void { libraryExercises(); }
export function __la_ext_action_libraryTraditional(_target: u32): void { libraryTraditional(); }
export function __la_ext_action_libraryClassical(_target: u32): void { libraryClassical(); }
export function __la_ext_action_libraryPrevious(_target: u32): void { libraryPrevious(); }
export function __la_ext_action_libraryNext(_target: u32): void { libraryNext(); }
export function __la_ext_action_libraryRowOne(_target: u32): void { libraryRowOne(); }
export function __la_ext_action_libraryRowTwo(_target: u32): void { libraryRowTwo(); }
export function __la_ext_action_libraryRowThree(_target: u32): void { libraryRowThree(); }
export function __la_ext_action_libraryRowFour(_target: u32): void { libraryRowFour(); }
export function __la_ext_action_openSettings(_target: u32): void { openSettings(); }
export function __la_ext_action_openHelp(_target: u32): void { openHelp(); }
export function __la_ext_action_lessonOne(_target: u32): void { lessonOne(); }
export function __la_ext_action_lessonTwo(_target: u32): void { lessonTwo(); }
export function __la_ext_action_lessonThree(_target: u32): void { lessonThree(); }
export function __la_ext_action_toggleHands(_target: u32): void { toggleHands(); }
export function __la_ext_action_toggleFingerColors(_target: u32): void { toggleFingerColors(); }
export function __la_ext_action_toggleLabels(_target: u32): void { toggleLabels(); }
export function __la_ext_action_toggleMetronome(_target: u32): void { toggleMetronome(); }
export function __la_ext_action_toggleInstructions(_target: u32): void { toggleInstructions(); }
export function __la_ext_action_volumeDown(_target: u32): void { volumeDown(); }
export function __la_ext_action_volumeUp(_target: u32): void { volumeUp(); }
export function __la_ext_action_cycleInstrument(_target: u32): void { cycleInstrument(); }
export function __la_ext_action_note48(_target: u32): void { activate(48); }
export function __la_ext_action_note49(_target: u32): void { activate(49); }
export function __la_ext_action_note50(_target: u32): void { activate(50); }
export function __la_ext_action_note51(_target: u32): void { activate(51); }
export function __la_ext_action_note52(_target: u32): void { activate(52); }
export function __la_ext_action_note53(_target: u32): void { activate(53); }
export function __la_ext_action_note54(_target: u32): void { activate(54); }
export function __la_ext_action_note55(_target: u32): void { activate(55); }
export function __la_ext_action_note56(_target: u32): void { activate(56); }
export function __la_ext_action_note57(_target: u32): void { activate(57); }
export function __la_ext_action_note58(_target: u32): void { activate(58); }
export function __la_ext_action_note59(_target: u32): void { activate(59); }
export function __la_ext_action_note60(_target: u32): void { activate(60); }
export function __la_ext_action_note61(_target: u32): void { activate(61); }
export function __la_ext_action_note62(_target: u32): void { activate(62); }
export function __la_ext_action_note63(_target: u32): void { activate(63); }
export function __la_ext_action_note64(_target: u32): void { activate(64); }
export function __la_ext_action_note65(_target: u32): void { activate(65); }
export function __la_ext_action_note66(_target: u32): void { activate(66); }
export function __la_ext_action_note67(_target: u32): void { activate(67); }
export function __la_ext_action_note68(_target: u32): void { activate(68); }
export function __la_ext_action_note69(_target: u32): void { activate(69); }
export function __la_ext_action_note70(_target: u32): void { activate(70); }
export function __la_ext_action_note71(_target: u32): void { activate(71); }
export function __la_ext_action_note72(_target: u32): void { activate(72); }
export function __la_ext_action_note73(_target: u32): void { activate(73); }
export function __la_ext_action_note74(_target: u32): void { activate(74); }
export function __la_ext_action_note75(_target: u32): void { activate(75); }
export function __la_ext_action_note76(_target: u32): void { activate(76); }
export function __la_ext_action_note77(_target: u32): void { activate(77); }
export function __la_ext_action_note78(_target: u32): void { activate(78); }
export function __la_ext_action_note79(_target: u32): void { activate(79); }
export function __la_ext_action_note80(_target: u32): void { activate(80); }
export function __la_ext_action_note81(_target: u32): void { activate(81); }
export function __la_ext_action_note82(_target: u32): void { activate(82); }
export function __la_ext_action_note83(_target: u32): void { activate(83); }
export function __la_ext_action_note84(_target: u32): void { activate(84); }
export function __la_ext_action_note85(_target: u32): void { activate(85); }
export function __la_ext_action_note86(_target: u32): void { activate(86); }
export function __la_ext_action_note87(_target: u32): void { activate(87); }
export function __la_ext_action_note88(_target: u32): void { activate(88); }
export function __la_ext_action_note89(_target: u32): void { activate(89); }
