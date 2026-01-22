cask "flowclip" do
  version "2.6.1"
  sha256 "301f9e1bd4515ac98f7660e3b08d9ca655a0f7c6178657c5ee13adbdd471c47b"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_2.6.1.zip"
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
