class FxHead < Formula
  desc "Terminal JSON viewer"
  homepage "https://fx.wtf"
  head "https://github.com/antonmedv/fx.git", branch: "master"
  license "MIT"

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(ldflags: "-s -w"), "-o", bin/"fx"
  end

  test do
    assert_equal "42", pipe_output(bin/"fx", 42).strip
  end
end
