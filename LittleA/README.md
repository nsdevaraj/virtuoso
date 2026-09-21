# LittleA iOS SDK

Add this directory as a local Swift package in Xcode and link the LittleA product.
Use `import LittleA` and `try LittleAEngine(bundleData: data)` to load a LAB.

Requires iOS 16 or later. LittleA is the thread-confined native CPU engine and
Swift API, including interpreted LittleScript. The optional LittleAUI product
adds a main-thread UIKit view, authored-rate clock, AVFoundation media, touch,
native IME/selection editing, and semantic accessibility elements.

Use `import LittleAUI`, create `LittleAView(frame:)`, then
`try view.load(bundleData: data, framesPerSecond: authoredFPS)` and
`try view.play()`. Mutate typed data through `view.engine` and call
`try view.refresh()` for immediate paused presentation. Removal, backgrounding
and interruptions pause playback and cancel held input; explicitly play to resume.
Call `view.dispose()` to release its scene, media, and display link.

The view renders CPU RGBA at point resolution, capped at four megapixels and
4096 pixels per axis. LAB input is capped at 64 MiB and FPS at 1-240. Media must
be embedded; decoding uses AVFoundation and may fail for unsupported codecs.
Audio uses the playback/mixWithOthers session category. Focused text fields use
a system-styled UITextView in their fitted semantic bounds. UIKit owns selection
handles and marked text; composition previews do not write bindings or emit
change events. Commit emits one change; cancel/pause/removal discard preedit.
External data writes supersede composition. UTF-16 selections bridge to
grapheme-aligned UTF-8 engine offsets. Single-line Return dismisses the keyboard.
Semantic activation and range/choice adjustments use live engine-local handles,
not pointer coordinates. Hidden/blocked/stale targets cannot act.
Multitouch gestures, physical-device accessibility/keyboard-language qualification,
custom-font/rotated editing parity, and native GPU rendering remain separately
scoped. No network resolver is installed.
At most 1024 cues and 64 active audio voices are admitted. Extended interactive
mono/stereo PCM (8-192 kHz, at most 64 MiB decoded per view) supports 1/16-16x
pitch, stereo balance, and sample-accurate gain fades. Pausing freezes playback
and fades; updates retain looping and position. Plain interactive sounds and
timeline/video retain their players; updating a plain voice promotes it to PCM.

The device and simulator libraries are unsigned. No registry or remote binary
download is required. See the included MIT and Apache licenses.
