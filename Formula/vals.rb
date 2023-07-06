class Vals < Formula
  desc "Helm-like configuration values loader with support for various sources"
  homepage "https://github.com/helmfile/vals"
  license "Apache-2.0"
  head "https://github.com/helmfile/vals.git", :branch => "main"

  depends_on "go" => :build

  def install
    system "make", "build"
    bin.install "bin/vals"
  end
end
