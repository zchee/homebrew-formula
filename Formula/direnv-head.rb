class DirenvHead < Formula
  desc "Load/unload environment variables based on $PWD"
  homepage "https://direnv.net/"
  head "https://github.com/direnv/direnv.git"

  depends_on "go" => :build

  def install
    ENV["GOPATH"] = buildpath
    (buildpath/"src/github.com/direnv/direnv").install buildpath.children

    ENV["GO111MODULE"] = "off"
    system "go", "get", "-u", "github.com/cpuguy83/go-md2man"
    ENV["GO111MODULE"] = "on"

    ENV.prepend_path "PATH", buildpath/"bin"
    cd "src/github.com/direnv/direnv" do
      system "make", "install", "DESTDIR=#{prefix}"
      prefix.install_metafiles
    end
  end

  test do
    system bin/"direnv", "status"
  end
end
