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

  patch :DATA

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

__END__
diff --git a/lib/vquic/curl_ngtcp2.c b/lib/vquic/curl_ngtcp2.c
index 0c9d50710..3818608dd 100644
--- a/lib/vquic/curl_ngtcp2.c
+++ b/lib/vquic/curl_ngtcp2.c
@@ -328,7 +328,7 @@ static void quic_settings(struct cf_ngtcp2_ctx *ctx,
   t->initial_max_streams_uni = QUIC_MAX_STREAMS;
   t->max_idle_timeout = QUIC_IDLE_TIMEOUT;
   if(ctx->qlogfd != -1) {
-    s->qlog.write = qlog_callback;
+    s->qlog_write = qlog_callback;
   }
 }
 
@@ -903,13 +903,13 @@ static int cb_get_new_connection_id(ngtcp2_conn *tconn, ngtcp2_cid *cid,
   return 0;
 }
 
-static int cb_recv_rx_key(ngtcp2_conn *tconn, ngtcp2_crypto_level level,
+static int cb_recv_rx_key(ngtcp2_conn *tconn, ngtcp2_encryption_level level,
                           void *user_data)
 {
   struct Curl_cfilter *cf = user_data;
   (void)tconn;
 
-  if(level != NGTCP2_CRYPTO_LEVEL_APPLICATION) {
+  if(level != NGTCP2_ENCRYPTION_LEVEL_1RTT) {
     return 0;
   }
 
@@ -1208,7 +1208,7 @@ static int cb_h3_stop_sending(nghttp3_conn *conn, int64_t stream_id,
   (void)conn;
   (void)stream_user_data;
 
-  rv = ngtcp2_conn_shutdown_stream_read(ctx->qconn, stream_id, app_error_code);
+  rv = ngtcp2_conn_shutdown_stream_read(ctx->qconn, 0, stream_id, app_error_code);
   if(rv && rv != NGTCP2_ERR_STREAM_NOT_FOUND) {
     return NGTCP2_ERR_CALLBACK_FAILURE;
   }
@@ -1226,7 +1226,7 @@ static int cb_h3_reset_stream(nghttp3_conn *conn, int64_t stream_id,
   (void)conn;
   (void)data;
 
-  rv = ngtcp2_conn_shutdown_stream_write(ctx->qconn, stream_id,
+  rv = ngtcp2_conn_shutdown_stream_write(ctx->qconn, 0, stream_id,
                                          app_error_code);
   DEBUGF(LOG_CF(data, cf, "[h3sid=%" PRId64 "] reset -> %d", stream_id, rv));
   if(rv && rv != NGTCP2_ERR_STREAM_NOT_FOUND) {
@@ -2403,7 +2403,7 @@ static CURLcode cf_ngtcp2_connect(struct Curl_cfilter *cf,
 
 out:
   if(result == CURLE_RECV_ERROR && ctx->qconn &&
-     ngtcp2_conn_is_in_draining_period(ctx->qconn)) {
+     ngtcp2_conn_in_draining_period(ctx->qconn)) {
     /* When a QUIC server instance is shutting down, it may send us a
      * CONNECTION_CLOSE right away. Our connection then enters the DRAINING
      * state.
