class CurlHead < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.haxx.se/"

  head do
    url "https://github.com/curl/curl.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "pkg-config" => :build
  depends_on "brotli"
  depends_on "c-ares"
  depends_on "libidn"
  depends_on "libmetalink"
  depends_on "libressl"
  depends_on "libssh2"
  depends_on "nghttp2"
  depends_on "openldap"
  depends_on "rtmpdump"
  depends_on "zlib"

  def install
    system "./buildconf" if build.head?

    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-optimize
      --enable-ipv6
      --enable-pthreads
      --enable-unix-sockets
      --enable-cookies
      --enable-ares=#{Formula["c-ares"].opt_prefix}
      --with-brotli=#{Formula["brotli"].opt_prefix}
      --with-ca-bundle=#{Formula["libressl"].pkgetc}/cert.pem
      --with-ca-path=#{Formula["libressl"].pkgetc}/certs
      --with-libidn2
      --with-libmetalink
      --with-librtmp
      --with-libssh2
      --with-nghttp2
      --with-ssl=#{Formula["libressl"].opt_prefix}
      --with-zlib=#{Formula["zlib"].opt_prefix}
      --with-zsh-functions-dir=#{prefix}/etc/zsh/site-functions
      --without-libpsl
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
