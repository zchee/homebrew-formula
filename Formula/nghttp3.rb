class Nghttp3 < Formula
  desc "HTTP/3 library written in C"
  homepage "https://github.com/ngtcp2/nghttp3"

  head do
    url "https://github.com/ngtcp2/nghttp3.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  def install
    ENV.cxx11

    args = %W[
      --prefix=#{prefix}
    ]

    system "autoreconf", "-i" if build.head?
    system "./configure", *args
    system "make"
    system "make", "install"
  end
end
