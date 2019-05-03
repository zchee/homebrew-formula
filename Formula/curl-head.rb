class CurlHead < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.haxx.se/"
  url "https://curl.haxx.se/download/curl-7.64.0.tar.bz2"
  sha256 "d573ba1c2d1cf9d8533fadcce480d778417964e8d04ccddcc76e591d544cf2eb"

  bottle do
    cellar :any
    sha256 "e5fa214a00a00fa80d76bd05db14e5c176a6be7bedeb86d748f5aa2969344f88" => :mojave
    sha256 "7349c533e22662c05ef5039696c3e8a7cd8d8a696797040c9c6bf27134662feb" => :high_sierra
    sha256 "0191dd2c0b129db3fcc10de4e5f61891ebe481a376cec04f8a2a4df5b389e9cb" => :sierra
  end

  head do
    url "https://github.com/curl/curl.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "libressl" => :build

    depends_on "zlib" => :build
    depends_on "brotli" => :build
    depends_on "libressl" => :build
    depends_on "libmetalink" => :build
    depends_on "libssh2" => :build
    depends_on "libssh" => :build
    depends_on "rtmpdump" => :build
    depends_on "libidn2" => :build
    depends_on "nghttp2" => :build
  end

  depends_on "pkg-config" => :build

  def install
    system "./buildconf" if build.head?

    args = %W[
      --prefix=#{prefix}
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-optimize
      --enable-ipv6
      --enable-pthreads
      --enable-unix-sockets
      --enable-cookies
      --with-zlib=#{Formula["zlib"].prefix}
      --with-brotli=#{Formula["brotli"].prefix}
      --without-darwinssl
      --with-ssl=#{Formula["libressl"].prefix}
      --with-ca-bundle=/usr/local/etc/ssl/certs/ca-bundle.crt
      --with-ca-path=/usr/local/etc/ssl/certs
      --with-libmetalink=#{Formula["libmetalink"].prefix}
      --with-libssh2=#{Formula["libssh2"].prefix}
      --with-libssh=#{Formula["libssh"].prefix}
      --with-librtmp=#{Formula["rtmpdump"].prefix}
      --with-libidn2=#{Formula["libidn2"].prefix}
      --with-nghttp2=#{Formula["nghttp2"].prefix}
      --with-zsh-functions-dir=#{prefix}/etc/zsh/site-functions
    ]

    system "./configure", *args
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "lib/mk-ca-bundle.pl"
    zsh_completion.install "#{prefix}/etc/zsh/site-functions/_curl"
  end

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    system libexec/"mk-ca-bundle.pl", "test.pem"
    assert_predicate testpath/"test.pem", :exist?
    assert_predicate testpath/"certdata.txt", :exist?
  end
end
