cask "flowclip" do
  version "1.0.1"
  sha256 "8ac4b975e82fe9de76ec5f960aa28792e1edf7d8cd14c55d046226a59adc329d"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_1.0.1.zip"
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
