// Wispr TeamViewer Fix: make synthetic Cmd+V (Wispr Flow, TextExpander, ...) work inside TeamViewer.
//
// Paste tools post one V keyDown with the Cmd flag set and no separate Cmd key press.
// TeamViewer forwards only modifiers it saw pressed, so the remote computer gets a bare "v".
// This event tap drops that V and replays it as modifier-down, V-down, V-up, modifier-up.
//
// Usage: wispr-teamviewer-fix [--key cmd|ctrl] [--wait ms] [--gap ms] [--selftest] [--version]
//   --key   modifier the REMOTE computer pastes with (cmd = Mac remote, ctrl = Windows remote)
//   --wait  pause before the replay so TeamViewer can sync the clipboard (default 150)
//   --gap   pause between the replayed events (default 30)
import Cocoa

let version = "1.0.0"
let args = CommandLine.arguments
func arg(_ name: String, _ fallback: String) -> String {
  guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
  return args[i + 1]
}

let useCtrl = arg("--key", "cmd") == "ctrl"
let keyName = useCtrl ? "ctrl" : "cmd"
let waitMs = min(UInt32(arg("--wait", "150")) ?? 150, 10_000)
let gapMs = min(UInt32(arg("--gap", "30")) ?? 30, 10_000)

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
func isSyntheticPaste(
  _ type: CGEventType, key: Int64, flags: CGEventFlags, physical: CGEventFlags, inTeamViewer: Bool
) -> Bool {
  inTeamViewer && type == .keyDown && key == vKey && flags.contains(.maskCommand)
    && !physical.contains(.maskCommand)
}

if args.contains("--version") {
  print("wispr-teamviewer-fix \(version)")
  exit(0)
}

if args.contains("--selftest") {
  precondition(isSyntheticPaste(.keyDown, key: 9, flags: .maskCommand, physical: [], inTeamViewer: true))
  precondition(!isSyntheticPaste(.keyDown, key: 9, flags: .maskCommand, physical: .maskCommand, inTeamViewer: true))
  precondition(!isSyntheticPaste(.keyDown, key: 9, flags: .maskCommand, physical: [], inTeamViewer: false))
  precondition(!isSyntheticPaste(.keyDown, key: 9, flags: [], physical: [], inTeamViewer: true))
  precondition(!isSyntheticPaste(.keyUp, key: 9, flags: .maskCommand, physical: [], inTeamViewer: true))
  precondition(!isSyntheticPaste(.keyDown, key: 8, flags: .maskCommand, physical: [], inTeamViewer: true))
  print("selftest ok")
  exit(0)
}

func teamViewerIsFrontmost() -> Bool {
  NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.hasPrefix("com.teamviewer") ?? false
}

func post(_ key: CGKeyCode, down: Bool, flags: CGEventFlags, modifier: Bool = false) {
  let e = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: key, keyDown: down)!
  if modifier { e.type = .flagsChanged }
  e.flags = flags
  e.setIntegerValueField(.eventSourceUserData, value: marker)
  e.post(tap: .cghidEventTap)
  usleep(gapMs * 1000)
}

func replayPaste() {
  usleep(waitMs * 1000)
  post(modKey, down: true, flags: modFlag, modifier: true)
  post(CGKeyCode(vKey), down: true, flags: modFlag)
  post(CGKeyCode(vKey), down: false, flags: modFlag)
  post(modKey, down: false, flags: [], modifier: true)
  log("replayed paste with \(keyName)")
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
  guard type == .keyDown, event.flags.contains(.maskCommand), teamViewerIsFrontmost() else { return pass }

  let physical = CGEventSource.flagsState(.hidSystemState)
  let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
  log("cmd+v in TeamViewer: source pid=\(pid) physicalCmd=\(physical.contains(.maskCommand))")
  if isSyntheticPaste(type, key: key, flags: event.flags, physical: physical, inTeamViewer: true) {
    swallowKeyUp = true
    replayQueue.async(execute: replayPaste)
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
log("wispr-teamviewer-fix \(version) running (remote pastes with \(keyName))")
CFRunLoopRun()
