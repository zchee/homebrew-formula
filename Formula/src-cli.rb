class SrcCli < Formula
  desc "Sourcegraph CLI"
  homepage "https://sourcegraph.com/"
  license "Apache-2.0"
  head "https://github.com/sourcegraph/src-cli.git"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = ["-s",
               "-w",
               "\"-extldflags=-static\""]

    system "go", "build", "-v", "-o", bin/"src-cli", "-ldflags", ldflags.join(" "), "./cmd/src"
  end

  test do
    system "#{bin}/src-cli", "version"
  end
end
