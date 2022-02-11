class Ngtcp2 < Formula
  desc "ngtcp2 project is an effort to implement IETF QUIC protocol"
  homepage "https://github.com/ngtcp2/ngtcp2"

  head do
    url "https://github.com/ngtcp2/ngtcp2.git", :branch => "main"

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
    cflags = "-std=c11 -flto"
    cxxflags = "-std=c++17 -stdlib=libc++"
    ldflags = "-flto"
    if Hardware::CPU.intel?
      cflags += " -march=native -Ofast"
      cxxflags = " -march=native -Ofast"
      ldflags += " -march=native -Ofast"
    else
      cflags += " -mcpu=apple-a14"
      cxxflags = " -mcpu=apple-a14"
      ldflags += " -mcpu=apple-a14"
    end

    ENV.append "CFLAGS", *cflags
    ENV.append "CXXFLAGS", *cxxflags
    ENV.append "LDFLAGS", *ldflags

    system "autoreconf", "-iv"
    system "./configure", "--prefix=#{prefix}", "--with-jemalloc", "--with-libnghttp3", "--with-libev", "--with-openssl"
    system "make", "check"
    system "make", "install"
  end
end
