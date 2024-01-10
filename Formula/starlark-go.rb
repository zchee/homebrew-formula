class StarlarkGo < Formula
  desc "Starlark in Go"
  homepage "https://https://github.com/google/starlark-go"
  license "BSD-3-Clause"
  head "https://github.com/google/starlark-go.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(output: bin/"starlark-go"), "./cmd/starlark"
  end
end
