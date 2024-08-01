class Protoscope < Formula
  desc "Protoscope is a simple, human-editable language for representing and emitting the Protobuf wire format."
  homepage "https://github.com/protocolbuffers/protoscope"
  license "Apache-2.0"
  head "https://github.com/protocolbuffers/protoscope.git", branch: "main"

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

    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}", "./cmd/protoscope"
    pkgshare.install "language.txt"
  end
end
