class WakatimeCli < Formula
  desc "Command line interface used by all WakaTime text editor plugins."
  homepage "https://github.com/wakatime/wakatime-cli"
  license "BSD-3-Clause"
  head "https://github.com/wakatime/wakatime-cli.git", branch: "develop"

  depends_on "go" => :build

  def install
    os = if OS.mac?
      "darwin"
    else
      "linux"
    end
    arch = Hardware::CPU.arm? ? "arm64" : "amd64"

    ldflags = %W[
      -s -w
      -X "github.com/wakatime/wakatime-cli/pkg/version.BuildDate=#{time}"
      -X "github.com/wakatime/wakatime-cli/pkg/version.Commit=#{version}"
      -X "github.com/wakatime/wakatime-cli/pkg/version.Version=<Homebrew-build>"
      -X "github.com/wakatime/wakatime-cli/pkg/version.OS=#{os}"
      -X "github.com/wakatime/wakatime-cli/pkg/version.Arch=#{arch}"
      -linkmode=external
      -buildmode=pie
      -buildid=
      "-extldflags=-static-pie -all_load -dead_strip -Wl,-no_deduplicate"
    ].join(" ")

    tags = %W[
      osusergo
      netgo
      static
    ].join(",")

    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}"
    bin.install_symlink "#{bin}/wakatime-cli" => "#{bin}/wakatime"
  end

  test do
    assert_match "Command line interface used by all WakaTime text editor plugins.", shell_output("#{bin}/wakatime-cli --help 2>&1")

    assert_match "error: Missing api key.", shell_output("#{bin}/wakatime --project test --today 2>&1", 104)
  end
end
