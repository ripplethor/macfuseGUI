cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.17"
  sha256 arm: "41b194b4cc5e56e4d98c06c48934336e908a291f268061fca42a5250ac47f643", intel: "d2337409d8b89684ff7647744314321d7075f8ca763d803d95a3d48dd6ffa126"

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
