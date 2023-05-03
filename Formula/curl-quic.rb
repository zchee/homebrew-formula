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
index 1ca1227b0..4bc10c7a7 100644
--- a/lib/vquic/curl_ngtcp2.c
+++ b/lib/vquic/curl_ngtcp2.c
@@ -140,7 +140,7 @@ struct cf_ngtcp2_ctx {
   uint32_t version;
   ngtcp2_settings settings;
   ngtcp2_transport_params transport_params;
-  ngtcp2_connection_close_error last_error;
+  ngtcp2_ccerr last_error;
   ngtcp2_crypto_conn_ref conn_ref;
 #ifdef USE_OPENSSL
   SSL_CTX *sslctx;
@@ -729,7 +729,7 @@ static int cb_recv_stream_data(ngtcp2_conn *tconn, uint32_t flags,
   DEBUGF(LOG_CF(data, cf, "[h3sid=%" PRId64 "] read_stream(len=%zu) -> %zd",
                 stream_id, buflen, nconsumed));
   if(nconsumed < 0) {
-    ngtcp2_connection_close_error_set_application_error(
+    ngtcp2_ccerr_set_application_error(
         &ctx->last_error,
         nghttp3_err_infer_quic_app_error_code((int)nconsumed), NULL, 0);
     return NGTCP2_ERR_CALLBACK_FAILURE;
@@ -788,7 +788,7 @@ static int cb_stream_close(ngtcp2_conn *tconn, uint32_t flags,
   DEBUGF(LOG_CF(data, cf, "[h3sid=%" PRId64 "] quic close(err=%"
                 PRIu64 ") -> %d", stream3_id, app_error_code, rv));
   if(rv) {
-    ngtcp2_connection_close_error_set_application_error(
+    ngtcp2_ccerr_set_application_error(
         &ctx->last_error, nghttp3_err_infer_quic_app_error_code(rv), NULL, 0);
     return NGTCP2_ERR_CALLBACK_FAILURE;
   }
@@ -1257,7 +1257,7 @@ static int init_ngh3_conn(struct Curl_cfilter *cf)
   int rc;
   int64_t ctrl_stream_id, qpack_enc_stream_id, qpack_dec_stream_id;
 
-  if(ngtcp2_conn_get_max_local_streams_uni(ctx->qconn) < 3) {
+  if(ngtcp2_conn_get_streams_uni_left(ctx->qconn) < 3) {
     return CURLE_QUIC_CONNECT_ERROR;
   }
 
@@ -1781,12 +1781,12 @@ static CURLcode recv_pkt(const unsigned char *pkt, size_t pktlen,
                   ngtcp2_strerror(rv)));
     if(!ctx->last_error.error_code) {
       if(rv == NGTCP2_ERR_CRYPTO) {
-        ngtcp2_connection_close_error_set_transport_error_tls_alert(
+        ngtcp2_ccerr_set_transport_error(
             &ctx->last_error,
             ngtcp2_conn_get_tls_alert(ctx->qconn), NULL, 0);
       }
       else {
-        ngtcp2_connection_close_error_set_transport_error_liberr(
+        ngtcp2_ccerr_set_transport_error(
             &ctx->last_error, rv, NULL, 0);
       }
     }
@@ -1874,7 +1874,7 @@ static ssize_t read_pkt_to_send(void *userp,
       if(veccnt < 0) {
         failf(x->data, "nghttp3_conn_writev_stream returned error: %s",
               nghttp3_strerror((int)veccnt));
-        ngtcp2_connection_close_error_set_application_error(
+        ngtcp2_ccerr_set_application_error(
             &ctx->last_error,
             nghttp3_err_infer_quic_app_error_code((int)veccnt), NULL, 0);
         *err = CURLE_SEND_ERROR;
@@ -1916,7 +1916,7 @@ static ssize_t read_pkt_to_send(void *userp,
         DEBUGASSERT(ndatalen == -1);
         failf(x->data, "ngtcp2_conn_writev_stream returned error: %s",
               ngtcp2_strerror((int)n));
-        ngtcp2_connection_close_error_set_transport_error_liberr(
+        ngtcp2_ccerr_set_transport_error(
             &ctx->last_error, (int)n, NULL, 0);
         *err = CURLE_SEND_ERROR;
         nwritten = -1;
@@ -1964,7 +1964,7 @@ static CURLcode cf_flush_egress(struct Curl_cfilter *cf,
   if(rv) {
     failf(data, "ngtcp2_conn_handle_expiry returned error: %s",
           ngtcp2_strerror(rv));
-    ngtcp2_connection_close_error_set_transport_error_liberr(&ctx->last_error,
+    ngtcp2_ccerr_set_liberr(&ctx->last_error,
                                                              rv, NULL, 0);
     return CURLE_SEND_ERROR;
   }
@@ -2317,7 +2317,7 @@ static CURLcode cf_connect_start(struct Curl_cfilter *cf,
   ngtcp2_conn_set_tls_native_handle(ctx->qconn, ctx->ssl);
 #endif
 
-  ngtcp2_connection_close_error_default(&ctx->last_error);
+  ngtcp2_ccerr_default(&ctx->last_error);
 
   ctx->conn_ref.get_conn = get_conn;
   ctx->conn_ref.user_data = cf;

