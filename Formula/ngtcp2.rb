class Ngtcp2 < Formula
  desc "ngtcp2 project is an effort to implement IETF QUIC protocol"
  homepage "https://github.com/ngtcp2/ngtcp2"

  head do
    url "https://github.com/ngtcp2/ngtcp2.git"

    depends_on "autoconf"
    depends_on "automake"
    depends_on "libtool"
  end

  depends_on "cunit" => :build
  depends_on "pkg-config" => :build
  depends_on "jemalloc"
  depends_on "libev"
  depends_on "nghttp3"
  depends_on "openssl-quic"

  uses_from_macos "zlib"

  def install
    ENV.cxx11

    ENV.append "LDFLAGS", "-Wl,-rpath,#{Formula["openssl-quic"].lib}"

    args = %W[
      --prefix=#{prefix}
      --disable-silent-rules
      --with-jemalloc
      --with-openssl
    ]

    system "autoreconf", "-i" if build.head?
    system "./configure", *args
    system "make"
    system "make", "check"
    system "make", "install"
  end
end
