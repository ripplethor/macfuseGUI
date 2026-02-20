cask "macfusegui" do
  arch arm: "arm64", intel: "x86_64"

  version "0.1.7"
  sha256 arm: "fba519f9ab20084e86bd79c9f383e5bfbb601687f94544165d5298fb7200e3a5", intel: "aee9c744a75cf5260d95a626d1654466ecb92f1af14cccef490041c1953c24ee"

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
