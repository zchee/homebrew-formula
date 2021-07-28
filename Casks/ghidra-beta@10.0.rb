cask "ghidra-beta@10.0" do
  version "10.0-BETA_PUBLIC_20210521"
  sha256 "f549dfccd0f106f9befb0b5afb7f2f86050356631b29bc9dd15d7f0333acbc7e"

  url "https://ghidra-sre.org/ghidra_#{version}.zip"
  name "Ghidra"
  homepage "https://www.ghidra-sre.org/"

  conflicts_with cask: "ghidra"

  binary "ghidra_10.0-BETA_PUBLIC/ghidraRun"

  # zap trash: "~/.ghidra"

  caveats do
    depends_on_java "11+"
  end
end
