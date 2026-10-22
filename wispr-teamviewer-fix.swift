// Wispr TeamViewer Fix: make synthetic Cmd+V (Wispr Flow, TextExpander, ...) work inside TeamViewer.
//
// Paste tools post one V keyDown with the Cmd flag set and no separate Cmd key press.
// TeamViewer forwards only modifiers it saw pressed, so the remote computer gets a bare "v".
// This event tap drops that V and replays it as modifier-down, V-down, V-up, modifier-up.
// Opt-in: Chrome 155/156 on macOS can drop a paste that comes right after a clipboard write
// (Chromium CL 8217390, fixed by CL 8503629 in Chrome 157), so the same replay runs late in Chrome.
//
// Usage: wispr-teamviewer-fix [--key cmd|ctrl] [--wait ms] [--gap ms] [--chrome-delay ms]
//                             [--selftest] [--version]
//   --key           modifier the REMOTE computer pastes with (cmd = Mac remote, ctrl = Windows remote)
//   --wait          pause before the replay so TeamViewer can sync the clipboard (default 150)
//   --gap           pause between the replayed events (default 30)
//   --chrome-delay  pause before a replayed Cmd+V in Chrome (default 0 = off, max 2000)
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
let chromeDelayMs = min(UInt32(arg("--chrome-delay", "0")) ?? 0, 2_000)

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

// The front app decides the replay. Chrome counts only when --chrome-delay is on.
func pasteTarget(bundleID: String?, chromeDelay: UInt32) -> Target? {
  guard let id = bundleID else { return nil }
  if id.hasPrefix("com.teamviewer") { return .teamViewer }
  if chromeDelay > 0 && id.hasPrefix("com.google.Chrome") { return .chrome }  // stable, beta, dev, canary
  return nil
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
  precondition(pasteTarget(bundleID: "com.teamviewer.TeamViewer", chromeDelay: 0) == .teamViewer)
  precondition(pasteTarget(bundleID: "com.google.Chrome", chromeDelay: 150) == .chrome)
  precondition(pasteTarget(bundleID: "com.google.Chrome", chromeDelay: 0) == nil)
  precondition(pasteTarget(bundleID: "com.google.Chrome.beta", chromeDelay: 150) == .chrome)
  precondition(pasteTarget(bundleID: "com.apple.Safari", chromeDelay: 150) == nil)
  precondition(pasteTarget(bundleID: nil, chromeDelay: 150) == nil)
  print("selftest ok")
  exit(0)
}

func post(_ key: CGKeyCode, down: Bool, flags: CGEventFlags, modifier: Bool = false) {
  let e = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: key, keyDown: down)!
  if modifier { e.type = .flagsChanged }
  e.flags = flags
  e.setIntegerValueField(.eventSourceUserData, value: marker)
  e.post(tap: .cghidEventTap)
  usleep(gapMs * 1000)
}

func replayPaste(wait: UInt32, mod: CGKeyCode, flag: CGEventFlags, done: String) {
  usleep(wait * 1000)
  post(mod, down: true, flags: flag, modifier: true)
  post(CGKeyCode(vKey), down: true, flags: flag)
  post(CGKeyCode(vKey), down: false, flags: flag)
  post(mod, down: false, flags: [], modifier: true)
  log(done)
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
      bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, chromeDelay: chromeDelayMs)
  else { return pass }

  let physical = CGEventSource.flagsState(.hidSystemState)
  let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
  log("cmd+v in \(target.rawValue): source pid=\(pid) physicalCmd=\(physical.contains(.maskCommand))")
  if isSyntheticPaste(type, key: key, flags: event.flags, physical: physical) {
    swallowKeyUp = true
    replayQueue.async {
      switch target {
      case .teamViewer:
        replayPaste(wait: waitMs, mod: modKey, flag: modFlag, done: "replayed paste with \(keyName)")
      case .chrome:  // local Chrome on this Mac: always Command, whatever --key says
        replayPaste(
          wait: chromeDelayMs, mod: 55, flag: .maskCommand, done: "replayed paste in Chrome after \(chromeDelayMs) ms")
      }
    }
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
    + (chromeDelayMs > 0 ? ", Chrome paste delay \(chromeDelayMs) ms" : ""))
CFRunLoopRun()
