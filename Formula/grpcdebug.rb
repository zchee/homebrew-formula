class Grpcdebug < Formula
  desc "grpcdebug is a command line interface focusing on simplifying the debugging process of gRPC applications."
  homepage "https://github.com/grpc-ecosystem/grpcdebug"
  license "Apache-2.0"
  head "https://github.com/grpc-ecosystem/grpcdebug.git", branch: "main"

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

    system "go", "mod", "tidy"
    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}"
  end
end
