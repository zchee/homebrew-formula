class DirenvHead < Formula
  desc "Load/unload environment variables based on $PWD"
  homepage "https://direnv.net/"
  license "MIT"
  head "https://github.com/direnv/direnv.git", branch: "master"

  depends_on "go" => :build
  depends_on "go-md2man" => :build

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
    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}", "-o=#{bin}/direnv"
    system "make", "man"
    man1.install Dir["man/*.1"]
  end

  test do
    system bin/"direnv", "status"
  end
end
