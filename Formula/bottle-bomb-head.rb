class BottleBombHead < Formula
  desc "Homebrew Bottle Downloader"
  homepage "https://github.com/blacktop/bottle-bomb"
  license "MIT"
  head "https://github.com/blacktop/bottle-bomb.git", branch: "main"

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

    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}"
  end
end
