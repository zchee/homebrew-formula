class Nghttp3 < Formula
  desc "HTTP/3 library written in C"
  homepage "https://github.com/ngtcp2/nghttp3"
  head "https://github.com/ngtcp2/nghttp3.git", :branch => "main"
  license "MIT"

  bottle :unneeded

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build

  def install
    ENV.cxx11

    system "autoreconf", "-iv"
    system "./configure", "--prefix=#{prefix}"
    system "make", "check"
    system "make", "install"
  end
end
