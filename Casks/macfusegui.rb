cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.14"
  sha256 arm: "4333574411601caf053ea30bf7372fcb5bd5ab400a1d199706fd82ff3f8e4d78", intel: "e1162f6800cd22f23ba10c34c57d1639d26499143549f8da4b18be843e7a5d69"

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
