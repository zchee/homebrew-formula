class ChromeCliHead < Formula
  desc "Control Google Chrome from the command-line"
  homepage "https://github.com/prasmussen/chrome-cli"
  license "MIT"
  head "https://github.com/prasmussen/chrome-cli.git", branch: "master"

  depends_on xcode: :build
  depends_on :macos

  def install
    inreplace "chrome-cli.xcodeproj/project.pbxproj", "MACOSX_DEPLOYMENT_TARGET = 10.9", "MACOSX_DEPLOYMENT_TARGET = 13.3"

    # Release builds
    xcodebuild "-arch", Hardware::CPU.arch, "SYMROOT=build"
    bin.install "build/Release/chrome-cli"

    # Install wrapper scripts for chrome compatible browsers
    bin.install "scripts/chrome-canary-cli"
    bin.install "scripts/chromium-cli"
    bin.install "scripts/brave-cli"
    bin.install "scripts/vivaldi-cli"
    bin.install "scripts/edge-cli"
  end

  test do
    system "#{bin}/chrome-cli", "version"
  end
end
