cask "firecamp-canary" do
  version "2.6.0"
  sha256 "36ca46c0affc7ce87661472b3bd0885a13404fd39a60d8cfb06b1248e27a9fb9"

  url "https://firecamp.ams3.digitaloceanspaces.com/canary/dmg/Firecamp%20Canary-#{version}.dmg",
      verified: "firecamp.ams3.digitaloceanspaces.com/"
  name "Firecamp Canary"
  desc "Multi-protocol API development platform"
  homepage "https://firecamp.io/"

  livecheck do
    url "https://firecamp.netlify.app/.netlify/functions/download?pt=mac"
    strategy :header_match
  end

  app "Firecamp Canary.app"

  zap trash: [
    "~/Library/Application Support/firecamp-canary",
    "~/Library/Preferences/com.firecamp.canary.plist",
    "~/.firecamp"
  ]
end
