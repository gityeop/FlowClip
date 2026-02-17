import Cocoa

class About {
  private let feedbackMessage = NSAttributedString(
    string: "Thanks for using FlowClip.\nWe'd love to hear your feedback.",
    attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor]
  )

  private var links: NSMutableAttributedString {
    let string = NSMutableAttributedString(string: "Website│GitHub│Support",
                                           attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    string.addAttribute(.link, value: "https://github.com/gityeop/FlowClip", range: NSRange(location: 0, length: 7))
    string.addAttribute(.link, value: "https://github.com/gityeop/FlowClip", range: NSRange(location: 8, length: 6))
    string.addAttribute(.link, value: "https://github.com/gityeop/FlowClip/issues", range: NSRange(location: 15, length: 7))
    return string
  }

  private var credits: NSMutableAttributedString {
    let credits = NSMutableAttributedString(string: "",
                                            attributes: [NSAttributedString.Key.foregroundColor: NSColor.labelColor])
    credits.append(links)
    credits.append(NSAttributedString(string: "\n\n"))
    credits.append(feedbackMessage)
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    return credits
  }

  @objc
  func openAbout(_ sender: NSMenuItem?) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}
