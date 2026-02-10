import AppKit.NSSound

extension NSSound {
  static let knock = NSSound(
    contentsOf: Bundle.main.url(forResource: "Knock", withExtension: "caf")!, byReference: true)
  static let write = NSSound(
    contentsOf: Bundle.main.url(forResource: "Write", withExtension: "caf")!, byReference: true)

  private static var activeFeedbackSounds: [NSSound] = []

  static func playMorseFeedback() {
    DispatchQueue.main.async {
      guard let sound = NSSound(contentsOfFile: "/System/Library/Sounds/Morse.aiff", byReference: true) else {
        return
      }

      activeFeedbackSounds.append(sound)
      sound.play()

      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        activeFeedbackSounds.removeAll { $0 === sound }
      }
    }
  }
}
