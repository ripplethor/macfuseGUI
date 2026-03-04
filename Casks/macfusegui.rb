cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.20"
  sha256 arm: "cecc8f0182a59504a8d0d37191969a0fee26d75cf023e970fa8a15a9f99754fc", intel: "5d9a0547b79df4a12d8ed3777731a7ad2e258b78161fe33465410f43e1a26c83"

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
