class Ngtcp2 < Formula
  desc "ngtcp2 project is an effort to implement IETF QUIC protocol"
  homepage "https://github.com/ngtcp2/ngtcp2"

  head do
    url "https://github.com/ngtcp2/ngtcp2.git"

    depends_on "pkg-config"
    depends_on "autoconf"
    depends_on "automake"
    depends_on "libtool"
  end

  depends_on "jemalloc"
  depends_on "libev"
  depends_on "nghttp3"
  depends_on "openssl-quic"

  def install
    ENV.append "CFLAGS", "-march=native -Ofast -flto=thin -std=c11"
    ENV.append "CXXFLAGS", "-march=native -Ofast -flto=thin -std=c++17 -stdlib=libc++"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto=thin"

    system "autoreconf", "-iv"
    system "./configure", "--prefix=#{prefix}", "--with-jemalloc", "--with-libnghttp3", "--with-libev", "--with-openssl"
    system "make", "check"
    system "make", "install"
  end
end
