cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.25"
  sha256 arm: "d7b006a1550fc106b120986fe650edb6ebaa5e47345a3c977d457033c2ea09bb", intel: "6a39485704e1bd02e7d48f1cf1dbab47db43d6c83fd1b2a401bc191ab82a15f0"

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
