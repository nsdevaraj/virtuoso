/* liblittlea — LittleA Engine C-ABI (Epic 2.1).
 *
 * Embed a LittleA scene in a native host (kiosk, signage, game engine):
 * load a `.lab` bundle, step the deterministic runtime, and rasterize
 * frames on the CPU (no GPU required). Link against liblittlea.a /
 * liblittlea.dylib / liblittlea.so, built by `cargo build -p la-ffi`.
 *
 * Every function tolerates a null handle/buffer (no-op or 0) — never UB.
 * See examples/embed.c for a complete usage sketch.
 */
#ifndef LITTLEA_H
#define LITTLEA_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque loaded scene. Create with littlea_load, destroy with littlea_free. */
/* A handle is single-threaded; never call it concurrently or move it between
 * threads. Bundled LittleScript uses the shared native host with the Pulley
 * bytecode interpreter (no browser, no JIT/executable-memory requirement). */
typedef struct Engine Engine;

/* Explicit shared global view-model lifetime. All aliases and attached engines
 * must be created, used and freed on the same thread, never concurrently.
 * Only models authored with scope="global" are shared; other data stays local. */
typedef struct GlobalDataScope GlobalDataScope;

/* Create an empty scope. Free releases only this handle, not the shared state;
 * loaded engines retain their own aliases. NULL free is a no-op. */
GlobalDataScope *littlea_global_scope_new(void);
void littlea_global_scope_free(GlobalDataScope *scope);

/* Clone aliases the same state (even when disposed); fork copies values,
 * declarations and defaults into an independent lifetime. NULL input fails;
 * fork also fails if disposed. Failure returns NULL with a scope diagnostic. */
GlobalDataScope *littlea_global_scope_clone(const GlobalDataScope *scope);
GlobalDataScope *littlea_global_scope_fork(const GlobalDataScope *scope);

/* Reset to the first registered defaults. Dispose invalidates shared data in
 * EVERY alias/engine but does not free handles. Dispose is idempotent.
 * These return 1 on success, 0 on failure with a scope diagnostic. */
int32_t littlea_global_scope_reset(const GlobalDataScope *scope);
int32_t littlea_global_scope_dispose(const GlobalDataScope *scope);
/* 1 disposed, 0 live, -1 for NULL (with a scope diagnostic). */
int32_t littlea_global_scope_is_disposed(const GlobalDataScope *scope);

/* Versioned JSON snapshot, UTF-8 and not NUL-terminated. NULL out queries the
 * length; otherwise copies up to out_len bytes; -1 on failure. Restore returns
 * 1 on success, 0 on invalid input/schema/disposal, with NO partial writes.
 * Neither operation includes or changes per-engine local view models.
 * Do not mutate the scope between the snapshot length and copy calls. */
int32_t littlea_global_scope_snapshot(const GlobalDataScope *scope,
                                       uint8_t *out, size_t out_len);
int32_t littlea_global_scope_restore(const GlobalDataScope *scope,
                                      const uint8_t *snapshot, size_t snapshot_len);

/* Last failed scope operation ON THIS THREAD. Successful scope operations
 * clear it; free and this accessor do not. Separate from load/script errors.
 * NULL out queries length, otherwise returns bytes copied; -1 if absent. */
int32_t littlea_last_global_scope_error(uint8_t *out, size_t out_len);

/* Push pending local/shared data through bindings and script extensions without
 * ticking. Call before render after peer writes or scope reset/restore.
 * Returns 1 if bindings changed, 0 if unchanged/NULL; script diagnostics follow
 * littlea_last_error just as with ticks/input. Does not change the playhead. */
int32_t littlea_refresh_data_bindings(Engine *engine);

/* Late-bound asset resolver. Return non-zero and write a borrowed byte span to
 * out_bytes/out_len when `name` is found. The returned bytes must remain valid
 * until the enclosing LittleA operation returns; the engine copies them before
 * it resumes that operation. */
typedef int32_t (*LittleAAssetResolver)(const uint8_t *name, size_t name_len,
                                        const uint8_t **out_bytes,
                                        size_t *out_len, void *user_data);

/* Load a `.lab` (bytes/len). Returns NULL if bytes is NULL or invalid. */
Engine *littlea_load(const uint8_t *bytes, size_t len);

/* As littlea_load, but instantiating the scene named `scene` rather than the
 * entry one. Returns NULL if the bundle holds no such scene. */
Engine *littlea_load_scene(const uint8_t *bytes, size_t len, const uint8_t *scene,
                           size_t scene_len);

/* Opt-in sharing, attached before bindings and script main. The scope is
 * borrowed, not consumed. NULL/disposed scopes and incompatible global schemas
 * return NULL and set littlea_last_load_error; no private-scope fallback.
 * Existing byte loaders above keep their independent local defaults. */
Engine *littlea_load_with_global_scope(const uint8_t *bytes, size_t len,
                                       const GlobalDataScope *scope);
Engine *littlea_load_scene_with_global_scope(const uint8_t *bytes, size_t len,
                                             const uint8_t *scene, size_t scene_len,
                                             const GlobalDataScope *scope);

/* Error from the most recent failed load ON THIS THREAD; successful loads
 * clear it. UTF-8, not NUL-terminated: NULL out queries length, otherwise
 * returns bytes copied; -1 means no error. Includes script load/main errors. */
int32_t littlea_last_load_error(uint8_t *out, size_t out_len);

/* Latest script runtime error for this engine, retained until free; same
 * string-copy convention. Entry-point/command failures stop further ticks
 * and input. Extension failures preserve fallback behavior and also appear
 * in warnings. Poll after ticks/input, even if those APIs return no status. */
int32_t littlea_last_error(const Engine *engine, uint8_t *out, size_t out_len);

/* --- Native component contracts ----------------------------------------
 * Component instance/input/output names and JSON are UTF-8 (ptr,len), never
 * NUL-terminated. JSON parsing, typed-kind checks, enum membership, finite
 * number checks, color spelling and the 1 MiB limit are enforced atomically by
 * the runtime. Component failures do not halt script or playback.
 *
 * Component diagnostics are per-thread and separate from load/script/global
 * diagnostics. Every successful component operation clears the last component
 * error. NULL out queries its UTF-8 byte length; a non-NULL buffer must fit the
 * complete error or -1 is returned without a partial copy. */
int32_t littlea_last_component_error(uint8_t *out, size_t out_len);

/* Write one typed input from scalar JSON. Returns 1 if the live value changed,
 * 0 if accepted but unchanged, and -1 on invalid handles/UTF-8/JSON, missing
 * ports, kind mismatches or rejected values. No partial component update is
 * performed on failure. */
int32_t littlea_set_component_input_json(
    Engine *engine, const uint8_t *instance, size_t instance_len,
    const uint8_t *input, size_t input_len,
    const uint8_t *json, size_t json_len);

/* Read one live typed output as scalar JSON. NULL out queries the required
 * byte length. A non-NULL buffer must fit the complete JSON value; insufficient
 * buffers return -1 without a partial copy. Returns -1 for invalid arguments
 * or missing/mismatched ports. */
int32_t littlea_component_output_json(
    const Engine *engine, const uint8_t *instance, size_t instance_len,
    const uint8_t *output, size_t output_len, uint8_t *out, size_t out_len);

/* Enter one component instance's declared local view state. An empty name
 * returns to the base state. Returns 1 when accepted, including when already
 * active, and 0 for invalid handles/UTF-8 or unknown instances/states. A
 * refusal sets littlea_last_component_error without affecting scene state.
 *
 * Readback returns the UTF-8 byte length for NULL out, copies the complete
 * non-NUL-terminated name into a fitting buffer, or returns -1 for invalid
 * input, an unknown instance, or a short buffer. An empty result is the base
 * state. Component states are independent between named instances. */
int32_t littlea_set_component_view_state(
    Engine *engine, const uint8_t *instance, size_t instance_len,
    const uint8_t *name, size_t name_len);
int32_t littlea_component_view_state(
    const Engine *engine, const uint8_t *instance, size_t instance_len,
    uint8_t *out, size_t out_len);

/* Enumerate declared local states in author order. Count returns -1 for
 * invalid input or an unknown instance. Name uses the same complete UTF-8
 * length/query convention as component_view_state and returns -1 for an
 * invalid index. The declaration list is independent of the active state. */
int32_t littlea_component_view_state_count(
    const Engine *engine, const uint8_t *instance, size_t instance_len);
int32_t littlea_component_view_state_name(
    const Engine *engine, const uint8_t *instance, size_t instance_len,
    uint32_t index, uint8_t *out, size_t out_len);

/* Drain notifications exactly once into Engine-owned cached JSON. Drain and
 * finish return 1 on success, -1 on error. A failed drain clears its previous
 * cache. Finish is terminal: it disposes every remaining registration once
 * and caches all pending lifecycle notifications before the engine is freed.
 *
 * The pure readback accessors never drain. NULL out repeatedly queries the
 * stable cached length and a fitting buffer repeatedly copies the same bytes
 * until the next corresponding drain. A non-NULL short buffer returns -1
 * without modifying either cache or output. Readback before a drain is -1.
 *
 * Lifecycle entries are:
 *   {"instance":string,"component":string,"callback":string,
 *    "phase":"create"|"dispose"}
 * Output entries are:
 *   {"instance":string,"component":string,"output":string,"value":scalar} */
int32_t littlea_drain_component_lifecycle_json(Engine *engine);
int32_t littlea_finish_component_lifecycle_json(Engine *engine);
int32_t littlea_component_lifecycle_json(
    const Engine *engine, uint8_t *out, size_t out_len);
int32_t littlea_drain_component_outputs_json(Engine *engine);
int32_t littlea_component_outputs_json(
    const Engine *engine, uint8_t *out, size_t out_len);

/* How many scenes the loaded bundle holds (0 if engine is NULL). */
uint32_t littlea_scene_count(const Engine *engine);

/* Copy scene `index`'s name (UTF-8) into out, returning bytes written, or the
 * full length when out is NULL, or -1 if index is out of range. Index 0 is
 * the entry scene. */
int32_t littlea_scene_name(const Engine *engine, uint32_t index, uint8_t *out,
                           size_t out_len);

/* --- Out-of-band assets -------------------------------------------------
 * `la bundle` warns and skips an asset it cannot read rather than failing,
 * so a .lab may reference art it does not carry. These let a host find those
 * references and fill them in. The count and every index are fixed at load,
 * so supplying an image while walking the list never shifts it. */

/* How many assets the loaded scenes reference, embedded or not. */
uint32_t littlea_asset_count(const Engine *engine);

/* Copy asset `index`'s path (UTF-8, not NUL-terminated) into out, returning
 * bytes written, or the full length when out is NULL, or -1 if index is out
 * of range. */
int32_t littlea_asset_name(const Engine *engine, uint32_t index, uint8_t *out,
                           size_t out_len);

/* Original encoded bytes of an Asset section, addressed by its bundle path
 * (e.g. "audio/theme.wav"), not a scene sound id. No decoding or filesystem/
 * network access. NULL out queries length; otherwise returns bytes copied,
 * up to out_len. Returns -1 for missing/invalid input; 0 for an empty asset.
 * Bytes stay unchanged until free, including after supply_image/load_font.
 * Audio/video hosts can copy these into their own platform decoder/storage. */
ptrdiff_t littlea_asset_data(const Engine *engine, const uint8_t *name,
                             size_t name_len, uint8_t *out, size_t out_len);

/* Resolve a cue/sound-request id to its declared asset path in the loaded
 * scene, then pass that path to asset_data. Returns -1 for an unknown id;
 * otherwise copies UTF-8 bytes (NULL out queries length). The source may be
 * declared even when its bytes were not embedded. */
int32_t littlea_sound_source(const Engine *engine, const uint8_t *id,
                             size_t id_len, uint8_t *out, size_t out_len);

/* Asset kind at `index`: 0 image, 1 video, 2 audio, 3 font; -1 if out of range.
 * Only images can be supplied — video and audio decode stays with the
 * platform. */
int32_t littlea_asset_kind(const Engine *engine, uint32_t index);

/* Whether a decoded image is available for asset `index`: 1 yes, 0 no,
 * -1 if out of range. For encoded audio/video/fonts use asset_data instead. */
int32_t littlea_asset_is_resolved(const Engine *engine, uint32_t index);

/* Supply PNG or JPEG bytes for a referenced image, or replace one already loaded.
 * Returns 1 if stored, 0 if refused — an unreferenced name (a host typo) and
 * bytes that do not decode are both refused, and any existing image is kept. */
int32_t littlea_supply_image(Engine *engine, const uint8_t *name,
                             size_t name_len, const uint8_t *encoded,
                             size_t encoded_len);

/* Register or clear a lazy resolver for missing PNG/JPEG image bytes. It is
 * consulted during render only; supply_image remains the eager path. */
int32_t littlea_set_asset_resolver(Engine *engine, LittleAAssetResolver resolver,
                                   void *user_data);
void littlea_clear_asset_resolver(Engine *engine);

/* Snapshot the decoded video frames needed by a render target. `fit` and
 * alignment must match the following littlea_render_rgba_fit call. Preparing
 * the next snapshot releases frames supplied for the previous one. */
int32_t littlea_prepare_video_frames(Engine *engine, uint32_t width,
                                     uint32_t height, const uint8_t *fit,
                                     size_t fit_len, float align_x,
                                     float align_y);
int32_t littlea_video_frame_source(const Engine *engine, uint32_t index,
                                   uint8_t *out, size_t out_len);
float littlea_video_frame_time(const Engine *engine, uint32_t index);
uint32_t littlea_video_frame_width(const Engine *engine, uint32_t index);
uint32_t littlea_video_frame_height(const Engine *engine, uint32_t index);
int32_t littlea_video_frame_muted(const Engine *engine, uint32_t index);
int32_t littlea_supply_video_frame(Engine *engine, uint32_t index,
                                   const uint8_t *rgba, size_t rgba_len);
void littlea_clear_video_frames(Engine *engine);

/* Register or drop a runtime font by the id that <mx:Label font=> names.
 * Invalid font bytes are refused, and unloaded/missing faces fall back to the
 * built-in atlas so text still draws. */
int32_t littlea_load_font(Engine *engine, const uint8_t *name, size_t name_len,
                          const uint8_t *font, size_t font_len);
int32_t littlea_unload_font(Engine *engine, const uint8_t *name, size_t name_len);

/* --- Diagnostics ---------------------------------------------------------
 * Non-fatal problems found while instantiating the scene: an unparseable
 * colour, an unresolved data binding, a listener naming a node that is not
 * there. The engine recovers from all of them, so a host that never reads
 * these cannot tell a correct scene from one that quietly fell back. */

/* How many diagnostics the loaded scene produced. */
uint32_t littlea_warning_count(const Engine *engine);

/* Copy diagnostic `index` (UTF-8, not NUL-terminated) into out, returning
 * bytes written, or the full length when out is NULL, or -1 if index is out
 * of range. */
int32_t littlea_warning(const Engine *engine, uint32_t index, uint8_t *out,
                        size_t out_len);

/* Free a handle from littlea_load. NULL is ignored. */
void littlea_free(Engine *engine);

/* Stage dimensions in pixels (0 if engine is NULL). */
uint32_t littlea_width(const Engine *engine);
uint32_t littlea_height(const Engine *engine);
/* Required RGBA buffer length for littlea_render_rgba (0 if engine is NULL). */
size_t littlea_render_rgba_required_len(const Engine *engine);

/* One authored script onFrame + scene step, including collisions/callbacks.
 * Call with 1/fps per authored frame; a host pauses scripts by not ticking.
 * Timeline pause/stop alone does not pause scripts (games may have no timeline).
 * A script trap is reported by littlea_last_error, never silently ignored. */
void littlea_tick(Engine *engine, float dt);

/* Host presentation backdrop as 0xRRGGBBAA. It clears the render surface
 * without mutating authored scene state. */
void littlea_set_background(Engine *engine, uint32_t rgba);
uint32_t littlea_background(const Engine *engine);

/* Root presentation transform as a row-major affine 3x3 matrix. It is
 * composed with viewport fitting at render time; perspective/non-finite
 * matrices are refused by the setter. */
int32_t littlea_set_transform(Engine *engine, const float *matrix);
int32_t littlea_get_transform(const Engine *engine, float *out);

/* Rasterize the current frame into a caller RGBA8 buffer (top-left origin,
 * width*height*4 bytes). Returns 1 on success, 0 if out is NULL/too small. */
int32_t littlea_render_rgba(Engine *engine, uint8_t *out, size_t out_len);

/* Rasterize into a width*height RGBA8 buffer, fitting the scene to it. `fit`
 * is one of "contain", "cover", "fill", "fit-width", "fit-height", "none",
 * "scale-down"; align_x/align_y run -1..1. Returns 1 on success, 0 if out is
 * NULL/too small or fit is not one of the seven. */
int32_t littlea_render_rgba_fit(Engine *engine, uint8_t *out, size_t out_len,
                                uint32_t width, uint32_t height,
                                const uint8_t *fit, size_t fit_len,
                                float align_x, float align_y);

/* Route a pointer-down at stage coordinates into widget interaction and
 * begin any declarative shape drag. */
void littlea_pointer_down(Engine *engine, float x, float y);

/* Route a pointer-move at stage coordinates (hover highlight + tooltips).
 * Returns 1 if the hovered widget changed (re-render), else 0. Coordinates
 * outside the stage clear the hover. */
int32_t littlea_pointer_move(Engine *engine, float x, float y);
/* Current CSS cursor name ("auto", "pointer", "grab", ...). Pass NULL out to
 * query its UTF-8 byte length. Returns -1 for a null engine. */
int32_t littlea_cursor(const Engine *engine, uint8_t *out, size_t out_len);

/* Continue a press-drag begun by littlea_pointer_down on a draggable shape
 * or position-driven control until littlea_pointer_up. Returns 1 if a shape
 * or control consumed it, else 0. Call on pointer-move while held. */
int32_t littlea_pointer_drag(Engine *engine, float x, float y);

/* Release capture and settle any shape drop at the last pointer position.
 * Call on pointer-up. Legacy hosts may also use this for cancellation. */
void littlea_pointer_up(Engine *engine);

/* Cancel capture without up/click/dragEnd listeners or a successful drop.
 * Unfinished draggable artwork returns home. Prior press/drag changes to
 * controls/data are retained. Use for OS cancellation, focus loss or hiding. */
void littlea_pointer_cancel(Engine *engine);

/* Held script keys AND declarative keyDown/keyUp listeners. Names match the
 * browser: ArrowLeft/Up/Right/Down, " " (also Space), Enter, Escape, Backspace,
 * Tab, ASCII letters/digits. Letter polling is case-insensitive; declarative
 * listeners receive the supplied spelling ("Space" normalizes to " ").
 * Returns 1 if a listener ran, 0 otherwise; held-key state still updates.
 * Text editing stays separate (littlea_text_key/littlea_type_text).
 * Forward releases, including on focus loss/gamepad cancellation. */
int32_t littlea_key_down(Engine *engine, const uint8_t *key, size_t key_len);
int32_t littlea_key_up(Engine *engine, const uint8_t *key, size_t key_len);

/* Global-timeline playhead control (mirrors the Web Player). */
void littlea_play(Engine *engine);
void littlea_stop(Engine *engine);
void littlea_seek(Engine *engine, float frame); /* seeks + re-applies */
float littlea_playhead(const Engine *engine);
/* Sample fractional playheads when non-zero; when zero, playback samples the
 * whole frame at floor(playhead) while the playhead itself remains fractional. */
void littlea_set_use_frame_interpolation(Engine *engine, int32_t use_frame_interpolation);
int32_t littlea_use_frame_interpolation(const Engine *engine);

/* Suspend playback keeping the playhead and loop progress, so littlea_play
 * resumes rather than restarts. */
void littlea_pause(Engine *engine);
int32_t littlea_is_playing(const Engine *engine);
/* Paused (suspended but resumable) is distinct from stopped. */
int32_t littlea_is_paused(const Engine *engine);

/* Playback rate multiplier; 1.0 is authored speed. Negative values are
 * ignored — play backwards with littlea_set_mode, so direction has exactly
 * one source of truth. */
void littlea_set_speed(Engine *engine, float speed);
float littlea_speed(const Engine *engine);

/* Play mode: 0 forward, 1 reverse, 2 bounce, 3 reverse-bounce. set_mode
 * returns 1 on success, 0 if the value is not one of those (leaving the
 * mode unchanged rather than silently defaulting). */
int32_t littlea_set_mode(Engine *engine, int32_t mode);
int32_t littlea_mode(const Engine *engine);

/* Confine playback to the inclusive frame range [start, end]. Looping,
 * bouncing and clamping all happen against the segment. */
void littlea_set_segment(Engine *engine, float start, float end);
void littlea_clear_segment(Engine *engine);

/* Passes before playback completes; 0 loops forever. */
void littlea_set_loop_count(Engine *engine, uint32_t count);
uint32_t littlea_loop_count(const Engine *engine);
uint32_t littlea_current_loop_count(const Engine *engine);
void littlea_reset_current_loop_count(Engine *engine);
void littlea_set_looping(Engine *engine, int32_t looping);

/* Scene extent: last keyframe, and the active range in seconds. */
uint32_t littlea_total_frames(const Engine *engine);
float littlea_duration(const Engine *engine);

/* Drain the pending loop / completion signals. Each crossing is reported
 * exactly once, so a host polls these once per tick. */
int32_t littlea_take_loop_event(Engine *engine);
int32_t littlea_take_complete_event(Engine *engine);

/* Take the oldest pending playback lifecycle event, or -1 when the queue
 * is empty: 0 load, 1 load-error, 2 play, 3 pause, 4 stop, 5 loop,
 * 6 complete. The engine reporting on its own playback, as distinct from
 * littlea_drain_events which carries events the content declared. Poll in
 * a loop once a frame until it returns -1. */
int32_t littlea_poll_player_event(Engine *engine);

/* State-machine observer reports: what the *interactivity model* did — states
 * entered and left, edges taken, triggers consumed — as distinct from
 * littlea_drain_events (events the content declared) and
 * littlea_poll_player_event (playback). A consumed trigger leaves no other
 * trace, so this is the only way to observe one. Drain once per frame, then
 * read each report by index.
 * kind: 0 state-entered, 1 state-exited, 2 transitioned, 3 input-fired,
 * 4 layer-stopped, 5 blend-completed; -1 if the index is out of range.
 * A tweened transition reports state-entered when it is taken and
 * blend-completed when the crossfade lands — the latter is the moment the
 * move is visually finished, and the one a state's entry actions run on.
 * name: the state for enter/exit, the DESTINATION for a transition, the input
 * for a fired trigger, empty for a stopped layer.
 * from: the ORIGIN of a transition; -1 for every other kind. */
/* OpenUrl: the one action that reaches outside the scene, and so the only one
 * gated by a policy. NOTHING is permitted until littlea_set_open_url_policy is
 * called — a .lottie can be downloaded from anywhere, so the engine must not
 * treat "the content asked for it" as reason enough to navigate. `patterns` is
 * a newline-separated UTF-8 list, each entry an exact host (example.com) or a
 * leading wildcard (*.example.com). Only http/https are ever eligible whatever
 * the list says: javascript:, data: and file: execute or read the disk rather
 * than navigate. `require_interaction` non-zero (the safe default) refuses to
 * open until the user has actually pressed something.
 * The engine never opens anything itself — it queues requests for the host,
 * because only the host knows what "open" means on its platform. */
int32_t littlea_set_open_url_policy(Engine *engine, const uint8_t *patterns,
                                    size_t patterns_len, int32_t require_interaction);
void littlea_deny_open_url(Engine *engine);
uint32_t littlea_drain_open_url_requests(Engine *engine);
ptrdiff_t littlea_open_url_request_url(const Engine *engine, uint32_t index,
                                       uint8_t *out, size_t out_len);
ptrdiff_t littlea_open_url_request_target(const Engine *engine, uint32_t index,
                                          uint8_t *out, size_t out_len);

/* Sounds a listener asked the host to start or stop (<mx:PlaySound> and
 * <mx:StopSound>), drained as one queue in the order the scene asked — a stop
 * followed by a play is a restart, and applying them the other way round
 * would leave silence.
 * These are REPORTED, never mixed. A <mx:Cue> belongs to a frame, so the
 * offline mixer renders it and `la test` hashes that schedule as the audio
 * determinism signature. A sound the user triggered happens when they click,
 * so scheduling one would make that signature depend on input timing and the
 * gate would stop being a gate. The engine queues the request; the host plays
 * it, exactly as with open-url above.
 * `_is_play` returns 1 for a play, 0 for a stop, -1 out of range. `_sound`
 * copies the clip id with the same conventions as the url readback above; an
 * empty id on a stop means "everything this scene started". `_gain` and
 * `_loops` describe a play and return -1 for a stop or a bad index. */
uint32_t littlea_drain_sound_requests(Engine *engine);
int32_t littlea_sound_request_is_play(const Engine *engine, uint32_t index);
/* is_play returns -2 for extended controls. kind: stop=0, play=1, playEx=2, update=3. */
int32_t littlea_sound_request_kind(const Engine *engine, uint32_t index);
/* field: pitch=0, pan=1, fade seconds=2; invalid request/field returns NaN. */
float littlea_sound_request_parameter(const Engine *engine, uint32_t index, uint32_t field);
/* update=0 plays; update=1 changes active named voices. Returns 0 on invalid/full. */
int32_t littlea_control_sound(Engine *engine, const uint8_t *sound, size_t sound_len,
                            float gain, int32_t looping, float pitch, float pan,
                            float fade, int32_t update);
ptrdiff_t littlea_sound_request_sound(const Engine *engine, uint32_t index,
                                      uint8_t *out, size_t out_len);
float littlea_sound_request_gain(const Engine *engine, uint32_t index);
int32_t littlea_sound_request_loops(const Engine *engine, uint32_t index);

/* Ask the host to play or silence a declared sound from host code, as
 * <mx:PlaySound>/<mx:StopSound> would. A null or empty `sound` on stop means
 * every sound this scene started. Both return 1 on success, 0 if the id
 * string is unusable. */
int32_t littlea_play_sound(Engine *engine, const uint8_t *sound,
                           size_t sound_len, float gain, int32_t looping);
int32_t littlea_stop_sound(Engine *engine, const uint8_t *sound,
                           size_t sound_len);

/* Resize the stage and re-resolve every layout that depends on it. Percent
 * sizes and edge constraints are authored against a parent and resolved once
 * at load, so a scene stays laid out for the viewport it was born with until
 * this is called — wire it to a window resize. Idempotent: passing the size
 * the stage already has re-resolves to the same answer. */
void littlea_resize(Engine *engine, float width, float height);
float littlea_stage_width(const Engine *engine);
float littlea_stage_height(const Engine *engine);

/* Enter a declared view state; an empty UTF-8 name leaves the active state.
 * Returns 1 on success, 0 for invalid input or a refused change. Script
 * failures are exposed through littlea_last_error. View-state animation
 * follows the scene's explicit transition policy. */
int32_t littlea_set_view_state(Engine *engine, const uint8_t *name, size_t name_len);
/* Active state name: bytes copied, required length for a null out pointer,
 * or -1 for an invalid engine. UTF-8, not NUL-terminated. An empty name
 * means no active view state. */
int32_t littlea_view_state(const Engine *engine, uint8_t *out, size_t out_len);

/* Whether any state machine is mid-crossfade, and how far through the first
 * blending layer is (eased, NaN when nothing is blending — test with isnan,
 * since an anticipatory curve legitimately dips below zero early on). A tweened
 * transition switches state immediately and fades the outgoing clip out
 * behind it, so "which state am I in" and "have I finished getting there" are
 * different questions; a state's entry actions run on the second. */
int32_t littlea_is_blending(const Engine *engine);
float littlea_blend_progress(const Engine *engine);

uint32_t littlea_drain_machine_reports(Engine *engine);
int32_t littlea_machine_report_kind(const Engine *engine, uint32_t index);
int32_t littlea_machine_report_layer(const Engine *engine, uint32_t index);
ptrdiff_t littlea_machine_report_name(const Engine *engine, uint32_t index,
                                      uint8_t *out, size_t out_len);
ptrdiff_t littlea_machine_report_from(const Engine *engine, uint32_t index,
                                      uint8_t *out, size_t out_len);

/* Runtime slots: host overrides of an already-loaded scene's own properties,
 * addressed by the node `id` the author wrote in .lax. A host ships one
 * bundle and recolours / relabels it per deployment without rebuilding.
 * Overrides are re-applied after every tick; clearing one restores the
 * authored value, which the runtime kept rather than trusting the host to
 * put back. Each `slot` is a UTF-8 (ptr,len) string. Setters return 1 on
 * success, 0 if a string argument is unusable. */
int32_t littlea_set_color_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                               uint32_t rgba);
int32_t littlea_set_image_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                               const uint8_t *src, size_t src_len);
int32_t littlea_set_text_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                              const uint8_t *text, size_t text_len);
int32_t littlea_set_scalar_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                                float value);
int32_t littlea_set_vector_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                                float x, float y);
int32_t littlea_set_position_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                                  float x, float y);
/* Draw a text node in a different declared <mx:Font>. The font's ID, not its
 * bytes: this retargets one node, where the asset resolver answers "what is
 * Inter.ttf?" for the whole scene. */
int32_t littlea_set_font_slot(Engine *engine, const uint8_t *slot, size_t slot_len,
                              const uint8_t *font, size_t font_len);
/* 0 color, 1 gradient, 2 image, 3 text, 4 scalar, 5 vector, 6 position,
 * 7 font; -1 when nothing is set for that slot. */
int32_t littlea_slot_type(const Engine *engine, const uint8_t *slot, size_t slot_len);
size_t littlea_slot_count(const Engine *engine);
int32_t littlea_clear_slot(Engine *engine, const uint8_t *slot, size_t slot_len);
void littlea_clear_slots(Engine *engine);
/* Animation themes are named runtime slot bundles, distinct from widget
 * chrome themes. Register JSON once, switch by id, or apply a JSON definition
 * directly; reset removes only the active theme's slots. Functions return 1
 * on success and 0 for malformed input or slot application errors. */
int32_t littlea_register_theme(Engine *engine, const uint8_t *id, size_t id_len,
                               const uint8_t *json, size_t json_len);
int32_t littlea_set_theme(Engine *engine, const uint8_t *id, size_t id_len);
int32_t littlea_set_theme_data(Engine *engine, const uint8_t *json, size_t json_len);
int32_t littlea_reset_theme(Engine *engine);

/* Glide the playhead to `frame` over `duration` seconds along the cubic
 * bezier (x1,y1,x2,y2) — a blend between two poses of the scene rather
 * than a cut. Returns 1 on success, 0 if the control points are not
 * finite. While a tween runs it owns the playhead; normal advancing is
 * suspended and restored when it lands. */
int32_t littlea_tween_to(Engine *engine, float frame, float duration,
                         float x1, float y1, float x2, float y2);
int32_t littlea_is_tweening(const Engine *engine);
void littlea_cancel_tween(Engine *engine);

/* Widget readback. `id` is a UTF-8 (ptr,len) string (not NUL-terminated). */
float littlea_widget_value(const Engine *engine, const uint8_t *id, size_t id_len);
/* 1 selected, 0 not, -1 unknown / not a checkable widget. */
int32_t littlea_widget_selected(const Engine *engine, const uint8_t *id, size_t id_len);
/* Copy a text field's text (TextInput or TextArea) into out (<= out_len);
 * returns bytes written, the full length if out is NULL, or -1 if id is
 * unknown / not a text field. A TextArea's text is '\n'-separated. */
int32_t littlea_widget_text(const Engine *engine, const uint8_t *id, size_t id_len,
                            uint8_t *out, size_t out_len);

/* Keyboard entry into the focused text field (TextInput or TextArea; focus
 * via littlea_pointer_down). */
int32_t littlea_type_text(Engine *engine, const uint8_t *text, size_t text_len);
int32_t littlea_backspace(Engine *engine);
/* Editing status: 1 changed/handled, 0 no change; -1 invalid argument,
   -2 unfocused, -3 not a text field, -4 non-grapheme UTF-8 boundary,
   -5 invalid text/control, -6 composition active, -7 no composition.
   Selection offsets are UTF-8 bytes, NOT UTF-16 code units. */
int32_t littlea_focus_text(Engine *engine, const uint8_t *id, size_t id_len);
int32_t littlea_text_selection(const Engine *engine, size_t *anchor, size_t *focus);
/* Focused native editing surface. handle is engine-local, selection is in
 * displayed/preedit UTF-8 bytes, and bounds are world-space, including transforms.
 * Returns 1, 0 for no visible/unblocked focused field, or -1 for invalid pointers.
 * Neither query below changes the semantics enumeration snapshot. */
typedef struct LittleATextInputInfo {
    uint32_t handle;
    size_t anchor;
    size_t focus;
    int32_t composing;
    int32_t multiline;
    float x, y, width, height;
} LittleATextInputInfo;
int32_t littlea_text_input_info(const Engine *engine, LittleATextInputInfo *out);
/* preview=0 reads the committed value; preview=1 includes marked text.
 * Null out queries UTF-8 length, otherwise returns bytes copied; -1 is
 * invalid/unfocused. Calls must be serialized with all engine mutations. */
int32_t littlea_text_input_text(const Engine *engine, int32_t preview,
                                uint8_t *out, size_t out_len);
int32_t littlea_set_text_selection(Engine *engine, size_t anchor, size_t focus);
int32_t littlea_replace_text(Engine *engine, const uint8_t *text, size_t text_len,
                            size_t anchor, size_t focus);
int32_t littlea_text_key(Engine *engine, const uint8_t *key, size_t key_len,
                        int32_t shift, int32_t command);
/* phase: 0 start, 1 update preview, 2 commit once, 3 cancel without change. */
int32_t littlea_composition(Engine *engine, uint32_t phase,
                           const uint8_t *text, size_t text_len);
/* Insert a line break into the focused TextArea (Enter); TextInput ignores. */
int32_t littlea_newline(Engine *engine);

/* State machine inputs + events — the two-way interactivity contract.
 * A host drives named inputs (<mx:Input>) and polls for named events
 * (<mx:Event> reported by an <mx:Listener>'s <mx:Notify>). `name` and `key`
 * are UTF-8 (ptr,len) strings, like the widget accessors above.
 *
 * A write reaches every state machine declaring that name, because a scene
 * may run several machines and only one need declare a given input. */
/* Set a bool input; 1 if any machine accepted it, else 0. */
int32_t littlea_set_bool(Engine *engine, const uint8_t *name, size_t name_len, int32_t value);
/* Set a number input; 1 if accepted. A non-finite value is refused (it
 * would freeze every comparison downstream). */
int32_t littlea_set_number(Engine *engine, const uint8_t *name, size_t name_len, float value);
/* Pulse a trigger input; 1 if accepted. The pulse latches until a
 * transition consumes it, so firing between ticks never loses it. */
int32_t littlea_fire_trigger(Engine *engine, const uint8_t *name, size_t name_len);

/* Set a `string` state-machine input; returns 1 if any machine accepted it.
 * Strings let a scene branch on the author's own vocabulary — a selected
 * tab, a difficulty, a locale — instead of magic numbers no one can read. */
int32_t littlea_set_string(Engine *engine, const uint8_t *name, size_t name_len,
                           const uint8_t *value, size_t value_len);
/* Copy a `string` input into out (<= out_len); returns bytes written, the
 * full length if out is NULL, or -1 if no machine declares it. */
ptrdiff_t littlea_string_input(const Engine *engine, const uint8_t *name, size_t name_len,
                               uint8_t *out, size_t out_len);
/* Restore an input to the value the scene authored — not zero, which is a
 * different thing for an input given a default. Clears an unconsumed trigger
 * pulse too. Returns 1 if any machine declares it. */
int32_t littlea_reset_input(Engine *engine, const uint8_t *name, size_t name_len);
/* Seed the deterministic RNG weighted transitions draw from, so a host can
 * pick a different but still reproducible stream. */
void littlea_set_seed(Engine *engine, uint64_t seed);
/* Read a bool input: 1 set, 0 clear, -1 if no machine declares it. */
int32_t littlea_bool_input(const Engine *engine, const uint8_t *name, size_t name_len);
/* Read a number input, or NaN if no machine declares it. */
float littlea_number_input(const Engine *engine, const uint8_t *name, size_t name_len);
/* Move the events reported since the last drain into the engine's readback
 * buffer and return how many. Call once a frame, then read each by index;
 * the buffer is replaced by the next drain. */
uint32_t littlea_drain_events(Engine *engine);
/* Copy drained event `index`'s name into out (<= out_len); returns bytes
 * written, the full length if out is NULL, or -1 if index is out of range. */
int32_t littlea_event_name(const Engine *engine, uint32_t index,
                           uint8_t *out, size_t out_len);
/* Copy drained event `index`'s property `key`, same convention as above;
 * -1 when the index or key is unknown. */
int32_t littlea_event_property(const Engine *engine, uint32_t index,
                               const uint8_t *key, size_t key_len,
                               uint8_t *out, size_t out_len);

/* Reactive data binding (view models) — the live, typed counterpart to the
 * {binding} template mechanism. A host writes named values and the runtime
 * pushes each onto whatever <mx:Bind> points it at, on the next tick.
 * `path` is a UTF-8 (ptr,len) string: either fully qualified ("hud.score")
 * or a bare property name, which resolves to the first model declaring it. */
/* Writes. 1 if the write landed, else 0 (unknown path, kind mismatch, or a
 * non-finite number, which is refused so it can't poison a transform). */
int32_t littlea_set_data_number(Engine *engine, const uint8_t *path, size_t path_len, float value);
int32_t littlea_set_data_text(Engine *engine, const uint8_t *path, size_t path_len,
                              const uint8_t *value, size_t value_len);
int32_t littlea_set_data_image(Engine *engine, const uint8_t *path, size_t path_len,
                               const uint8_t *value, size_t value_len);
int32_t littlea_fire_data_trigger(Engine *engine, const uint8_t *path, size_t path_len);
int32_t littlea_set_data_boolean(Engine *engine, const uint8_t *path, size_t path_len, int32_t value);
/* Colour is 0xRRGGBBAA, like every other colour in the runtime. */
int32_t littlea_set_data_color(Engine *engine, const uint8_t *path, size_t path_len, uint32_t value);
/* Reads. NaN / -1 / 0 respectively when the path is unknown or holds a
 * different kind. */
float littlea_data_number(const Engine *engine, const uint8_t *path, size_t path_len);
int32_t littlea_data_boolean(const Engine *engine, const uint8_t *path, size_t path_len);
uint32_t littlea_data_color(const Engine *engine, const uint8_t *path, size_t path_len);
/* Copy a string property into out (<= out_len); returns bytes written, the
 * full length if out is NULL, or -1 if unknown / another kind. */
int32_t littlea_data_text(const Engine *engine, const uint8_t *path, size_t path_len,
                          uint8_t *out, size_t out_len);
int32_t littlea_data_image(const Engine *engine, const uint8_t *path, size_t path_len,
                           uint8_t *out, size_t out_len);
uint64_t littlea_data_trigger_generation(const Engine *engine, const uint8_t *path, size_t path_len);
/* Enumerate the declared contract. Paths are sorted, so index order is
 * stable across runs. */
uint32_t littlea_data_path_count(const Engine *engine);
int32_t littlea_data_path_name(const Engine *engine, uint32_t index,
                               uint8_t *out, size_t out_len);
/* 0 number, 1 string, 2 boolean, 3 color, 4 enum, 5 image, 6 trigger,
 * -1 index out of range. */
int32_t littlea_data_path_kind(const Engine *engine, uint32_t index);

/* Audio schedule (real-time playback). The engine owns the deterministic
 * cue schedule (<mx:Cue>); a host reads it and plays each named clip with
 * its own audio backend (Web Audio, cpal, ...). The PCM is the host's to
 * decode and mix — like video, audio decode is platform-delegated. */
/* Number of scheduled cues (0 if engine is NULL). */
uint32_t littlea_audio_event_count(const Engine *engine);
/* Cue start frame (0 if index is out of range). */
uint32_t littlea_audio_event_frame(const Engine *engine, uint32_t index);
/* Cue gain multiplier (NaN if index is out of range). */
float littlea_audio_event_gain(const Engine *engine, uint32_t index);
/* 1 if the clip loops, 0 one-shot, -1 if index is out of range. */
int32_t littlea_audio_event_looping(const Engine *engine, uint32_t index);
/* Cue kind: 0 = SFX (one-shot), 1 = BGM (music), -1 if index out of range. */
int32_t littlea_audio_event_kind(const Engine *engine, uint32_t index);
/* Copy the cue's clip id (the <mx:Sound id> to load the WAV for; UTF-8)
 * into out (<= out_len); returns bytes written, the full length if out is
 * NULL, or -1 if index is out of range. */
int32_t littlea_audio_event_clip(const Engine *engine, uint32_t index,
                                 uint8_t *out, size_t out_len);
/* FNV-1a signature of the cue schedule (0 if engine is NULL), distinct from
 * the visual frame signature. */
uint64_t littlea_audio_signature(const Engine *engine);

/* Set an enum view-model property by NAME; 1 if the write landed, 0 if the
 * name is not one the property declares. littlea_data_enum_value reads the
 * assignable names back (bytes written, full length if out is NULL, or -1
 * for a bad path or index). */
int32_t littlea_set_data_enum(Engine *engine, const uint8_t *path,
                              size_t path_len, const uint8_t *value,
                              size_t value_len);
int32_t littlea_data_enum_value(const Engine *engine, const uint8_t *path,
                                size_t path_len, uint32_t index, uint8_t *out,
                                size_t out_len);

/* Scrolling. littlea_scroll_by is the wheel entry point; littlea_fling sets
 * a pane coasting at a speed the HOST measured from the gesture, after
 * which it decays in time (not per frame) so a flick travels the same
 * distance at any frame rate. Both return 1 on success, 0 otherwise. */
int32_t littlea_scroll_by(Engine *engine, const uint8_t *id, size_t id_len,
                          float delta);
/* Route wheel/trackpad deltas to the innermost named pane under a stage-space
 * point, respecting visible hit geometry and modal capture. Returns 1 moved,
 * 0 unhandled/at limit, -1 for NULL/nonfinite arguments. */
int32_t littlea_scroll_at(Engine *engine, float x, float y, float dx, float dy);
/* Bring id into its nearest ScrollPane. align: 0 nearest, 1 start, 2 center,
 * 3 end. Returns 1 when the pane moved. */
int32_t littlea_scroll_into_view(Engine *engine, const uint8_t *id,
                                 size_t id_len, int32_t align);
int32_t littlea_fling(Engine *engine, const uint8_t *id, size_t id_len,
                      float velocity);

/* Reduced motion. The runtime cannot read a platform accessibility setting,
 * so a host forwards it — and re-forwards it when it changes. Motion stops;
 * input, state machines and rigs keep running. A timeline carrying a
 * "reduced" frame label rests there; one without holds where it is. */
/* Returns 1 if applied, 0 if engine is NULL. */
int32_t littlea_set_reduced_motion(Engine *engine, int32_t reduced);
/* 1 if reduced motion is in force, else 0. */
int32_t littlea_reduced_motion(const Engine *engine);

/* Accessibility semantics. A canvas tells assistive technology nothing, so
 * a host builds the platform's accessibility objects from these: a role, a
 * name, live state, and a box to point at, for every element of the scene
 * worth announcing. Roles and state kinds are ABI — new ones are only ever
 * appended. */
#define LITTLEA_ROLE_TEXT      0
#define LITTLEA_ROLE_BUTTON    1
#define LITTLEA_ROLE_CHECKBOX  2
#define LITTLEA_ROLE_RADIO     3
#define LITTLEA_ROLE_SLIDER    4
#define LITTLEA_ROLE_STEPPER   5
#define LITTLEA_ROLE_TEXTFIELD 6
#define LITTLEA_ROLE_LISTBOX   7
#define LITTLEA_ROLE_COMBOBOX  8
#define LITTLEA_ROLE_TABLIST   9
#define LITTLEA_ROLE_IMAGE     10
#define LITTLEA_ROLE_GROUP     11

/* How to read the floats littlea_semantics_state writes. */
#define LITTLEA_STATE_NONE   0  /* no numbers */
#define LITTLEA_STATE_TOGGLE 1  /* [checked] */
#define LITTLEA_STATE_RANGE  2  /* [value, min, max] */
#define LITTLEA_STATE_TEXT   3  /* no numbers; see littlea_semantics_text */
#define LITTLEA_STATE_CHOICE 4  /* [selected, count, expanded] */

/* Rebuild the visible, modal-filtered snapshot and return its length
 * (0 if engine is NULL). Every accessor below reads that snapshot by index,
 * so call this first and again whenever the scene may have changed. */
uint32_t littlea_semantics_count(Engine *engine);
/* Stable engine-local handle, not an enumeration index. Returns 1 or -1.
 * Never use a handle with another engine, including after scene replacement. */
int32_t littlea_semantics_handle(const Engine *engine, uint32_t index, uint32_t *out);
#define LITTLEA_ACTION_FOCUS        0
#define LITTLEA_ACTION_ACTIVATE     1
#define LITTLEA_ACTION_INCREMENT    2
#define LITTLEA_ACTION_DECREMENT    3
#define LITTLEA_ACTION_SET_VALUE    4
#define LITTLEA_ACTION_SELECT_INDEX 5
/* Revalidate against live visibility/modal/widget state, then apply the native
 * action, bindings and script/event callbacks. No pointer/drag events.
 * value is used only by SET_VALUE and SELECT_INDEX (an integer >= -1).
 * Returns 1 on success, 0 if script input is halted, -1 for invalid arguments,
 * or -2 for a hidden/retired/blocked target or incompatible action/range. */
int32_t littlea_semantic_action(Engine *engine, uint32_t handle, uint32_t action,
                                double value);
/* LITTLEA_ROLE_* of the element, or -1 if index is out of range. */
int32_t littlea_semantics_role(const Engine *engine, uint32_t index);
/* Copy the element's name (UTF-8) into out (<= out_len); returns bytes
 * written, the full length if out is NULL, or -1 if index is out of range. */
int32_t littlea_semantics_label(const Engine *engine, uint32_t index,
                                uint8_t *out, size_t out_len);
/* As above for an editable field's CONTENTS, which are not its name;
 * additionally returns -2 if the element is not a text field. */
int32_t littlea_semantics_text(const Engine *engine, uint32_t index,
                               uint8_t *out, size_t out_len);
/* Write up to out_len floats of live state and return the LITTLEA_STATE_*
 * kind that says how to read them, or -1 if index is out of range. Writes
 * nothing at all if out_len is too short for that kind. */
int32_t littlea_semantics_state(const Engine *engine, uint32_t index,
                                float *out, size_t out_len);
/* Write world-space x, y, width, height (four floats) and return 0, or -1
 * if index is out of range or out_len is under four. */
int32_t littlea_semantics_bounds(const Engine *engine, uint32_t index,
                                 float *out, size_t out_len);

/* liblittlea version, packed (major<<16)|(minor<<8)|patch, so a host can
 * detect which library it linked against. Always safe to call. */
uint32_t littlea_version(void);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* LITTLEA_H */
