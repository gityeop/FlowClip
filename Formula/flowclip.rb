cask "flowclip" do
  version "1.0.5"
  sha256 "2b0f0581e86545dee33a74d057718de02cab1f30a8c36d9211c4057f27049df9"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_1.0.5.zip"
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
