class DirenvHead < Formula
  desc "Load/unload environment variables based on $PWD"
  homepage "https://direnv.net/"
  license "MIT"
  head "https://github.com/direnv/direnv.git", branch: "master"

  depends_on "go" => :build
  depends_on "go-md2man" => :build

  def install
    system "make", "install", "PREFIX=#{prefix}"
  end

  test do
    system bin/"direnv", "status"
  end
end
