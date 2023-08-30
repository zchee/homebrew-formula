class Tfvar < Formula
  desc "Terraform's variable definitions template generator"
  homepage "https://github.com/shihanng/tfvar"
  head "https://github.com/shihanng/tfvar.git", branch: "trunk"
  license "MIT"

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w")
  end
end
