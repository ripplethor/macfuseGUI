cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.25"
  sha256 arm: "71df1ed7f77c29dc380f36553aa5a12142e40aa2b7d73ac158ac507db3719849", intel: "dce18a088ef789b90fb54dcb88e03b5a4c494c98359b34a79422402e8f2e74a2"

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
