class Txtpbfmt < Formula
  desc "txtpbfmt parses, edits and formats text proto files in a way that preserves comments."
  homepage "https://github.com/protocolbuffers/txtpbfmt"
  license "Apache-2.0"
  head "https://github.com/protocolbuffers/txtpbfmt.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = %W[
      -s -w
    ]
    tags = %W[
      osusergo
      netgo
      static
    ].join(",")

    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}", "./cmd/txtpbfmt"
    pkgshare.install "docs/config.md"
    pkgshare.install "docs/examples"
  end
end
