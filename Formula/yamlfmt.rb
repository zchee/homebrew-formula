class Yamlfmt < Formula
  desc "An extensible command line tool or library to format yaml files"
  homepage "https://github.com/google/yamlfmt"
  head "https://github.com/google/yamlfmt.git", branch: "main"
  license "Apache-2.0"

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
    ].join(" ")

    tags = %W[
      osusergo
      netgo
      static
    ].join(",")

    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}", "./cmd/yamlfmt"
  end
end
