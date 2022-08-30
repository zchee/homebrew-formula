class SrcCli < Formula
  desc "Sourcegraph CLI"
  homepage "https://sourcegraph.com/"
  license "Apache-2.0"
  head "https://github.com/sourcegraph/src-cli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
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
    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}", "./cmd/src"
  end

  test do
    system "#{bin}/src-cli", "version"
  end
end
