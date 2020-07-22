class CurlQuic < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server with QUIC"
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
  depends_on "libssh2"
  depends_on "nghttp2"
  depends_on "nghttp3"
  depends_on "ngtcp2"
  depends_on "openldap"
  depends_on "openssl-quic"
  depends_on "rtmpdump"
  depends_on "zstd"

  patch :DATA if not build.head?

  def install
    system "./buildconf" if build.head?
    
    ENV.append "CFLAGS", "-march=native -Ofast -flto"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto"
    
    openssl_quic = Formula["openssl-quic"]
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
      --with-ssl=yes
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

  def caveats
    <<~EOS
      curl-quic formula needs to --env=std flag
    EOS
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

__END__
diff --git a/configure.ac b/configure.ac
index ed1b5fcec..e69dc561f 100755
--- a/configure.ac
+++ b/configure.ac
@@ -1751,7 +1751,7 @@ if test -z "$ssl_backends" -o "x$OPT_SSL" != xno &&
       dnl only do pkg-config magic when not cross-compiling
       PKGTEST="yes"
     fi
-    PREFIX_OPENSSL=/usr/local/ssl
+    PREFIX_OPENSSL=/usr/local/opt/openssl-quic
     LIB_OPENSSL="$PREFIX_OPENSSL/lib$libsuff"
     ;;
   off)
