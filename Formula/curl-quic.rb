class CurlQuic < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server with QUIC"
  homepage "https://curl.haxx.se/"
  head "https://github.com/curl/curl.git"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "brotli" => :build
  depends_on "c-ares" => :build
  depends_on "libidn" => :build
  depends_on "libmetalink" => :build
  depends_on "libssh2" => :build
  depends_on "libtool" => :build
  depends_on "nghttp2" => :build
  depends_on "nghttp3" => :build
  depends_on "ngtcp2" => :build
  depends_on "openldap" => :build
  depends_on "openssl-quic" => :build
  depends_on "pkg-config" => :build
  depends_on "rtmpdump" => :build
  depends_on "zstd" => :build

  def install
    system "./buildconf"
    
    ENV.append "CFLAGS", "-march=native -Ofast -flto"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto"
    ENV.prepend "CPPFLAGS", "-isystem #{Formula["openssl-quic"].include}"
    ENV.prepend "LDFLAGS", "-L#{Formula["openssl-quic"].lib}"

    ENV["LIBTOOLIZE"] = Formula["libtool"].bin/"glibtool"
    
    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-ares=#{Formula["c-ares"].opt_prefix}
      --with-ca-bundle=#{etc}/openssl-quic/cert.pem
      --with-ca-path=#{etc}/openssl-quic/certs
      --with-gssapi
      --with-libidn2
      --with-libmetalink
      --with-librtmp
      --with-libssh2
      --with-ssl=#{Formula["openssl-quic"].opt_prefix}
      --with-nghttp3=#{Formula["nghttp3"].opt_prefix}
      --with-ngtcp2=#{Formula["ngtcp2"].opt_prefix}
      --without-quiche
      --enable-alt-svc
      --without-libpsl
    ]
    
    system "./configure", *args
    system "make", "install"

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
