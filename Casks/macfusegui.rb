cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.7"
  sha256 arm: "6c34c1b236228c38796310fe3fff18ca41dcf2acd4ddcfaff2c91466ddf7bcb4", intel: "632b547930d1aa13f8bef7b86479e2fa005cfd23ff472d322815797c0bf08560"

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
