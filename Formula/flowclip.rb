cask "flowclip" do
  version "1.0.2"
  sha256 "97b0d463e5cea734c9d67352db4533df36df2d435bc06951d8237661cb75df3e"

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
