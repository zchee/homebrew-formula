class FqHead < Formula
  desc "jq for binary formats"
  homepage "https://github.com/wader/fq"
  license "MIT"
  head "https://github.com/wader/fq.git", branch: "master"

  depends_on "go" => :build

  def install
    system "make", "fq"
    bin.install "fq"
  end
end
