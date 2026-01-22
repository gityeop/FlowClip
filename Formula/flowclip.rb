cask "flowclip" do
  version "1.0.2"
  sha256 "4eb14fd775a444f4809dccc21d209b7687049b6f913e2268239b2a18596cf73f"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_1.0.2.zip"
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
