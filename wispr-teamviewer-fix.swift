// Wispr TeamViewer Fix: make synthetic Cmd+V (Wispr Flow, TextExpander, ...) work inside TeamViewer.
//
// Paste tools post one V keyDown with the Cmd flag set and no separate Cmd key press.
// TeamViewer forwards only modifiers it saw pressed, so the remote computer gets a bare "v".
// This event tap drops that V and replays it as modifier-down, V-down, V-up, modifier-up.
// Opt-in: Chrome 155/156 on macOS cancels a paste that comes right after a clipboard write
// (Chromium CL 8217390, fixed by CL 8503629 in Chrome 157). With --chrome-type, a synthetic Cmd+V
// in Chrome is dropped and the clipboard text is typed as Unicode key events instead.
//
// Usage: wispr-teamviewer-fix [--key cmd|ctrl] [--wait ms] [--gap ms] [--chrome-type]
//                             [--selftest] [--version]
//   --key          modifier the REMOTE computer pastes with (cmd = Mac remote, ctrl = Windows remote)
//   --wait         pause before the replay so TeamViewer can sync the clipboard (default 150)
//   --gap          pause between the replayed events (default 30)
//   --chrome-type  type the clipboard text instead of a synthetic Cmd+V in Chrome (default off)
import Cocoa

let version = "1.1.0"
let args = CommandLine.arguments
func arg(_ name: String, _ fallback: String) -> String {
  guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
  return args[i + 1]
}

let useCtrl = arg("--key", "cmd") == "ctrl"
let keyName = useCtrl ? "ctrl" : "cmd"
let waitMs = min(UInt32(arg("--wait", "150")) ?? 150, 10_000)
let gapMs = min(UInt32(arg("--gap", "30")) ?? 30, 10_000)
let chromeType = args.contains("--chrome-type")
let typePauseMs: UInt32 = 2  // between typed events in Chrome

let marker: Int64 = 0x7476_7066  // tags our own events so the tap ignores them
let vKey: Int64 = 9  // kVK_ANSI_V
let modKey: CGKeyCode = useCtrl ? 59 : 55  // kVK_Control : kVK_Command
let modFlag: CGEventFlags = useCtrl ? .maskControl : .maskCommand
var swallowKeyUp = false
let replayQueue = DispatchQueue(label: "replay")  // serial: two quick pastes never mix
var tap: CFMachPort?

// Same format as `log show`, so a line here matches TeamViewer's lines in the macOS log.
let clock = DateFormatter()
clock.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
func log(_ line: String) { print("\(clock.string(from: Date())) \(line)") }

// A V keyDown that claims Cmd while the physical Cmd key is up came from software.
func isSyntheticPaste(_ type: CGEventType, key: Int64, flags: CGEventFlags, physical: CGEventFlags) -> Bool {
  type == .keyDown && key == vKey && flags.contains(.maskCommand) && !physical.contains(.maskCommand)
}

enum Target: String { case teamViewer = "TeamViewer", chrome = "Chrome" }

// The front app decides the replay. Chrome counts only when --chrome-type is on.
func pasteTarget(bundleID: String?, chromeType: Bool) -> Target? {
  guard let id = bundleID else { return nil }
  if id.hasPrefix("com.teamviewer") { return .teamViewer }
  if chromeType && id.hasPrefix("com.google.Chrome") { return .chrome }  // stable, beta, dev, canary
  return nil
}

enum TypingChunk: Equatable { case text(String), newline }

// Split text for typing: one key event carries at most maxUTF16 units (macOS drops more than 20),
// a Character is never split, and each line break (\n, \r\n or \r) becomes its own chunk.
func typingChunks(_ s: String, maxUTF16: Int = 20) -> [TypingChunk] {
  var chunks: [TypingChunk] = []
  var run = ""
  func flush() {
    if !run.isEmpty { chunks.append(.text(run)) }
    run = ""
  }
  for c in s {  // "\r\n" is one Character
    if c == "\n" || c == "\r" || c == "\r\n" {
      flush()
      chunks.append(.newline)
    } else {
      if run.utf16.count + c.utf16.count > maxUTF16 { flush() }
      run.append(c)
    }
  }
  flush()
  return chunks
}

if args.contains("--version") {
  print("wispr-teamviewer-fix \(version)")
  exit(0)
}

if args.contains("--selftest") {
  precondition(isSyntheticPaste(.keyDown, key: 9, flags: .maskCommand, physical: []))
  precondition(!isSyntheticPaste(.keyDown, key: 9, flags: .maskCommand, physical: .maskCommand))
  precondition(!isSyntheticPaste(.keyDown, key: 9, flags: [], physical: []))
  precondition(!isSyntheticPaste(.keyUp, key: 9, flags: .maskCommand, physical: []))
  precondition(!isSyntheticPaste(.keyDown, key: 8, flags: .maskCommand, physical: []))
  precondition(pasteTarget(bundleID: "com.teamviewer.TeamViewer", chromeType: false) == .teamViewer)
  precondition(pasteTarget(bundleID: "com.google.Chrome", chromeType: true) == .chrome)
  precondition(pasteTarget(bundleID: "com.google.Chrome", chromeType: false) == nil)
  precondition(pasteTarget(bundleID: "com.google.Chrome.beta", chromeType: true) == .chrome)
  precondition(pasteTarget(bundleID: "com.apple.Safari", chromeType: true) == nil)
  precondition(pasteTarget(bundleID: nil, chromeType: true) == nil)
  let a = { (n: Int) in String(repeating: "a", count: n) }
  precondition(typingChunks("") == [])
  precondition(typingChunks(a(45)) == [.text(a(20)), .text(a(20)), .text(a(5))])
  precondition(typingChunks("a\nb") == [.text("a"), .newline, .text("b")])
  precondition(typingChunks("a\r\nb") == [.text("a"), .newline, .text("b")])
  precondition(typingChunks("a\rb") == [.text("a"), .newline, .text("b")])
  precondition(typingChunks("\n") == [.newline])
  let thumbs = { (n: Int) in String(repeating: "👍", count: n) }  // 2 UTF-16 units each
  precondition(typingChunks(thumbs(15)) == [.text(thumbs(10)), .text(thumbs(5))])
  precondition(typingChunks(a(19) + "e\u{301}") == [.text(a(19)), .text("e\u{301}")])  // é stays whole
  precondition(typingChunks("a👨‍👩‍👧‍👦b", maxUTF16: 4) == [.text("a"), .text("👨‍👩‍👧‍👦"), .text("b")])
  print("selftest ok")
  exit(0)
}

func post(
  _ key: CGKeyCode, down: Bool, flags: CGEventFlags, modifier: Bool = false, text: [UniChar] = [],
  pauseMs: UInt32 = gapMs
) {
  let e = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: key, keyDown: down)!
  if modifier { e.type = .flagsChanged }
  if !text.isEmpty { e.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text) }
  e.flags = flags
  e.setIntegerValueField(.eventSourceUserData, value: marker)
  e.post(tap: .cghidEventTap)
  usleep(pauseMs * 1000)
}

func replayPaste() {
  usleep(waitMs * 1000)
  post(modKey, down: true, flags: modFlag, modifier: true)
  post(CGKeyCode(vKey), down: true, flags: modFlag)
  post(CGKeyCode(vKey), down: false, flags: modFlag)
  post(modKey, down: false, flags: [], modifier: true)
  log("replayed paste with \(keyName)")
}

// Type text as Unicode key events. A line break is Shift+Return: a new line, not "send", in chat boxes.
func typeText(_ s: String) {
  func key(_ code: CGKeyCode, _ down: Bool, _ flags: CGEventFlags, modifier: Bool = false, text: [UniChar] = []) {
    post(code, down: down, flags: flags, modifier: modifier, text: text, pauseMs: typePauseMs)
  }
  for chunk in typingChunks(s) {
    switch chunk {
    case .text(let t):
      key(0, true, [], text: Array(t.utf16))
      key(0, false, [], text: Array(t.utf16))
    case .newline:
      key(56, true, .maskShift, modifier: true)  // kVK_Shift
      key(36, true, .maskShift)  // kVK_Return
      key(36, false, .maskShift)
      key(56, false, [], modifier: true)
    }
  }
}

let callback: CGEventTapCallBack = { _, type, event, _ in
  let pass = Unmanaged.passUnretained(event)
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    return pass
  }
  // Every other key returns here at once.
  let key = event.getIntegerValueField(.keyboardEventKeycode)
  guard key == vKey, event.getIntegerValueField(.eventSourceUserData) != marker else { return pass }

  if type == .keyDown { swallowKeyUp = false }  // the paste app sent no key-up last time
  if type == .keyUp && swallowKeyUp {
    swallowKeyUp = false
    return nil
  }
  guard type == .keyDown, event.flags.contains(.maskCommand),
    let target = pasteTarget(
      bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, chromeType: chromeType)
  else { return pass }

  let physical = CGEventSource.flagsState(.hidSystemState)
  let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
  let synthetic = isSyntheticPaste(type, key: key, flags: event.flags, physical: physical)
  let source = "cmd+v in \(target.rawValue): source pid=\(pid) physicalCmd=\(physical.contains(.maskCommand))"
  if target == .chrome && synthetic {
    // Read the text now: Wispr puts the old clipboard back about 0.5 s later.
    guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
      log("cmd+v in Chrome: no text on the clipboard, passed through")
      return pass
    }
    log(source)
    swallowKeyUp = true
    replayQueue.async {
      typeText(text)
      log("typed \(text.count) characters in Chrome")  // the count only: never log the text
    }
    return nil
  }
  log(source)
  if synthetic {
    swallowKeyUp = true
    replayQueue.async { replayPaste() }
    return nil
  }
  return pass
}

func makeTap() -> CFMachPort? {
  let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
  return CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
    callback: callback, userInfo: nil)
}

setvbuf(stdout, nil, _IOLBF, 0)
tap = makeTap()
if tap == nil {
  // Show the macOS permission window and add the app to the Accessibility list.
  _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
  log("Waiting for Accessibility access...")
  // AXIsProcessTrusted() can stay false in a running process after the user turns access on.
  // Creating the tap is checked again by macOS on each call, so retry that instead.
  while tap == nil {
    sleep(2)
    tap = makeTap()
  }
  log("Accessibility access granted")
}
guard let tap else { exit(1) }
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
log(
  "wispr-teamviewer-fix \(version) running (remote pastes with \(keyName))"
    + (chromeType ? ", Chrome typing mode on" : ""))
CFRunLoopRun()
