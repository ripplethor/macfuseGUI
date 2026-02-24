cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.10"
  sha256 arm: "15a2d1f26c5da0a7d3040d5588898500699b9c416e6eebcf53413bad334b07df", intel: "4601a4c2518742067c69e74ffa6d24d3254b71e183814364bd93730d574683ae"

  url "https://github.com/ripplethor/macfuseGUI/releases/download/v#{version}/macfuseGui-v#{version}-macos-#{arch}.dmg",
      verified: "github.com/ripplethor/macfuseGUI/"
  name "macfuseGui"
  desc "SSHFS GUI for macOS using macFUSE"
  homepage "https://www.macfusegui.app/"

  depends_on macos: ">= :ventura"

  app "macFUSEGui.app"

  caveats <<~EOS
    This app is unsigned and not notarized.
    If macOS blocks launch, run:
      xattr -dr com.apple.quarantine "/Applications/macFUSEGui.app"
  EOS
end
