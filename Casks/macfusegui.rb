cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.26"
  sha256 arm: "64e49cd55041c5096ba566bff455b6a3d7379f5b91bc881641280732c97c6dae", intel: "5b47dd17bfbdd895f0db29e7ec0a129d237da0450084099e18da5e63f1299202"

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
