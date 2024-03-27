class WakatimeCliHead < Formula
  desc "Command line interface used by all WakaTime text editor plugins."
  homepage "https://github.com/wakatime/wakatime-cli"
  license "BSD-3-Clause"
  head "https://github.com/wakatime/wakatime-cli.git", branch: "develop"

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"

    arch = Hardware::CPU.intel? ? "amd64" : Hardware::CPU.arch.to_s
    ldflags = %W[
      -s -w
      -X github.com/wakatime/wakatime-cli/pkg/version.Arch=#{arch}
      -X github.com/wakatime/wakatime-cli/pkg/version.BuildDate=#{time.iso8601}
      -X github.com/wakatime/wakatime-cli/pkg/version.Commit=#{Utils.git_head(length: 7)}
      -X github.com/wakatime/wakatime-cli/pkg/version.OS=#{OS.kernel_name.downcase}
      -X github.com/wakatime/wakatime-cli/pkg/version.Version=v#{version}
    ].join(" ")
    tags = %W[
      osusergo
      netgo
      static
    ].join(",")

    system "go", "build", "-buildmode=pie", "-tags=#{tags}", *std_go_args(ldflags: ldflags), "-o=#{bin}/wakatime-cli"
    bin.install_symlink "#{bin}/wakatime-cli" => "#{bin}/wakatime"
  end

  test do
    output = shell_output("#{bin}/wakatime-cli --help 2>&1")
    assert_match "Command line interface used by all WakaTime text editor plugins", output
  end
end
