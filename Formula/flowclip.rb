cask "flowclip" do
  version "1.0.4"
  sha256 "faadb94eb68b93fe5f0a08ee81d632b118c1b42a72f4397b1b6f4f7e29324602"

  url "https://github.com/gityeop/FlowClip/releases/download/v#{version}/FlowClip_1.0.4.zip"
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
