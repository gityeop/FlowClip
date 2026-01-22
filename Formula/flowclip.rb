cask "flowclip" do
  version "1.0.0"
  sha256 "0eb6a1fc90b6bd9e9423daf4a758840b978ba2059f6189eb54b3a75c702f882f"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_1.0.0.zip"
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
