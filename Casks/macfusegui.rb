cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.7"
  sha256 arm: "f25d6c25386d088261b0300bc1c4087b2849662c0aab16b1d11f117d362cdc0c", intel: "a0b56a6818519f26fc52d396b5935a45fa32b6d7983d5b1e58612114f3a7f2a4"

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
