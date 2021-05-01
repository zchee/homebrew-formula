class CurlQuic < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server with QUIC"
  homepage "https://curl.haxx.se/"
  license "curl"

  bottle :unneeded

  head do
    url "https://github.com/curl/curl.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build

    depends_on "brotli" => :build
    depends_on "c-ares" => :build
    depends_on "libidn2" => :build
    depends_on "libmetalink" => :build
    depends_on "libssh2" => :build
    depends_on "nghttp2" => :build
    depends_on "nghttp3" => :build
    depends_on "ngtcp2" => :build
    depends_on "openldap" => :build
    depends_on "openssl-quic" => :build
    depends_on "pkg-config" => :build
    depends_on "rtmpdump" => :build
    depends_on "zstd" => :build
  end

  def install
    system "autoreconf", "-fiv"

    ENV.append "CFLAGS", "-march=native -Ofast -flto=thin"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto=thin"
    ENV.prepend "CPPFLAGS", "-isystem #{Formula["openssl-quic"].include}"
    ENV.prepend "LDFLAGS", "-L#{Formula["openssl-quic"].lib}"
    
    openssl_quic = Formula["openssl-quic"]
    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-ares=#{Formula["c-ares"].opt_prefix}
      --with-ca-bundle=#{openssl_quic.pkgetc}/cert.pem
      --with-ca-path=#{openssl_quic.pkgetc}/certs
      --with-secure-transport
      --with-default-ssl-backend=openssl
      --with-ssl=#{openssl_quic.opt_prefix}
      --with-nghttp3=#{Formula["nghttp3"].opt_prefix}
      --with-ngtcp2=#{Formula["ngtcp2"].opt_prefix}
      --without-quiche
      --enable-alt-svc
      --with-gssapi
      --with-libidn2
      --with-libmetalink
      --with-librtmp
      --with-libssh2
      --without-libpsl
    ]
    
    system "./configure", *args
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "lib/mk-ca-bundle.pl"
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
