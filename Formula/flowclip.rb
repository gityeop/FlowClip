cask "flowclip" do
  version "1.0.3"
  sha256 "a64f8c0866e4440fb170fb56fc3a760b06a379f87bd20e1d109ff51d42d9f4d2"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_1.0.3.zip"
  name "FlowClip"
  desc "Clipboard manager with Queue support (Fork of Maccy)"
  homepage "https://github.com/gityeop/FlowClip"

  auto_updates true
  conflicts_with cask: "maccy"
  depends_on macos: ">= :mojave"

  app "FlowClip.app"

  uninstall quit: "com.gityeop.FlowClip"

  zap trash: [
    "~/Library/Preferences/com.gityeop.FlowClip.plist",
    "~/Library/Application Support/FlowClip",
  ]
end
