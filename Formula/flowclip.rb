cask "flowclip" do
  version "1.0.3"
  sha256 "4ac3109aeebb336e19ca514f9096d51aa988f6471725a63afc869ff69108e337"

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
