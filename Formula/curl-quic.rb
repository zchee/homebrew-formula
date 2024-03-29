class CurlQuic < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server with QUIC"
  homepage "https://curl.haxx.se/"
  license "curl"

  livecheck do
    url "https://curl.se/download/"
    regex(/href=.*?curl[._-]v?(.*?)\.t/i)
  end

  head do
    url "https://github.com/curl/curl.git", :branch => "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :head

    depends_on "brotli" => :build
    depends_on "c-ares" => :build
    depends_on "libidn2" => :build
    depends_on "libssh2" => :build
    depends_on "libnghttp2" => :build
    depends_on "nghttp3" => :build
    depends_on "ngtcp2" => :build
    depends_on "openldap" => :build
    depends_on "openssl-quic" => :build
    depends_on "pkg-config" => :build
    depends_on "rtmpdump" => :build
    depends_on "zstd" => :build

    uses_from_macos "krb5"
    uses_from_macos "zlib"
  end

  def install
    system "autoreconf", "-fiv"

    cflags = "-std=c11 -flto"
    ldflags = "-flto"
    if Hardware::CPU.intel?
      cflags += " -march=native -Ofast"
      ldflags += " -march=native -Ofast"
    else
      cflags += " -mcpu=apple-a14"
      ldflags += " -mcpu=apple-a14"
    end
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags
    # ENV.prepend "CPPFLAGS", "-isystem #{openssl_quic.opt_prefix}/include"
    # ENV.prepend "LDFLAGS", "-L#{openssl_quic.opt_prefix}/lib"
    # ENV.prepend "LIBS", "-lngtcp2_crypto_openssl"

    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-ssl=#{Formula["openssl-quic"].opt_prefix}
      --enable-ares=#{Formula["c-ares"].opt_prefix}
      --without-ca-bundle
      --without-ca-path
      --with-ca-fallback
      --with-secure-transport
      --with-default-ssl-backend=openssl
      --with-nghttp3=#{Formula["nghttp3"].opt_prefix}
      --with-ngtcp2=#{Formula["ngtcp2"].opt_prefix}
      --enable-headers-api
      --without-quiche
      --enable-alt-svc
      --enable-websockets
      --with-libidn2
      --with-librtmp
      --with-libssh2
      --without-libpsl
    ]

    args << if OS.mac?
      "--with-gssapi"
    else
      "--with-gssapi=#{Formula["krb5"].opt_prefix}"
    end

    system "./configure", *args
    system "make", "install"
    system "make", "install", "-C", "scripts"
    libexec.install "scripts/mk-ca-bundle.pl"
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
