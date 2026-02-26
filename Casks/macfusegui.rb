cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.15"
  sha256 arm: "d5820d5f0e13e6f3c042cc8c5d573dd1d71511af8707b22a996515fd813a3854", intel: "8321482cc0c95d8634355e6fcc8a13282fae0f5524c3c2262c7bd3e51c382250"

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
