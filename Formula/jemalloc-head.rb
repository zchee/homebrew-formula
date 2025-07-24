class JemallocHead < Formula
  desc "Implementation of malloc emphasizing fragmentation avoidance"
  homepage "https://github.com/facebook/jemalloc"
  license "BSD-2-Clause"

  head do
    url "https://github.com/facebook/jemalloc.git", branch: "dev"

    depends_on "autoconf" => :build
    depends_on "docbook-xsl" => :build
    depends_on "libxslt" => :build

    patch :DATA
  end

  def install
    args = %W[
      --disable-debug
      --prefix=#{prefix}
      --with-jemalloc-prefix=
      --enable-experimental-fp-prefetch
    ]

    if build.head?
      args << "--with-xslroot=#{Formula["docbook-xsl"].opt_prefix}/docbook-xsl"
      system "./autogen.sh", *args
      system "make", "dist"
    else
      system "./configure", *args
    end

    system "make"
    # Do not run checks with Xcode 15, they fail because of
    # overly eager optimization in the new compiler:
    # https://github.com/jemalloc/jemalloc/issues/2540
    # Reported to Apple as FB13209585
    system "make", "check" if DevelopmentTools.clang_build_version < 1500
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdlib.h>
      #include <jemalloc/jemalloc.h>

      int main(void) {

        for (size_t i = 0; i < 1000; i++) {
            // Leak some memory
            malloc(i * 100);
        }

        // Dump allocator statistics to stderr
        malloc_stats_print(NULL, NULL, NULL);
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-ljemalloc", "-o", "test"
    system "./test"
  end
end

__END__
diff --git a/configure.ac b/configure.ac
index c703a6d10..1b655cef2 100644
--- a/configure.ac
+++ b/configure.ac
@@ -1434,6 +1434,22 @@ if test "x$enable_experimental_smallocx" = "x1" ; then
 fi
 AC_SUBST([enable_experimental_smallocx])
 
+dnl Do not enable fastpath prefetch by default.
+AC_ARG_ENABLE([experimental_fp_prefetch],
+  [AS_HELP_STRING([--enable-experimental-fp-prefetch], [Enable experimental fastpath prefetch])],
+[if test "x$enable_experimental_fp_prefetch" = "xno" ; then
+enable_experimental_fp_prefetch="0"
+else
+enable_experimental_fp_prefetch="1"
+fi
+],
+[enable_experimental_fp_prefetch="0"]
+)
+if test "x$enable_experimental_fp_prefetch" = "x1" ; then
+  AC_DEFINE([JEMALLOC_EXPERIMENTAL_FASTPATH_PREFETCH], [ ], [ ])
+fi
+AC_SUBST([enable_experimental_fp_prefetch])
+
 dnl Do not enable profiling by default.
 AC_ARG_ENABLE([prof],
   [AS_HELP_STRING([--enable-prof], [Enable allocation profiling])],
diff --git a/include/jemalloc/internal/jemalloc_internal_defs.h.in b/include/jemalloc/internal/jemalloc_internal_defs.h.in
index 31ae2e8ed..3a945ba1e 100644
--- a/include/jemalloc/internal/jemalloc_internal_defs.h.in
+++ b/include/jemalloc/internal/jemalloc_internal_defs.h.in
@@ -160,6 +160,11 @@
 /* JEMALLOC_EXPERIMENTAL_SMALLOCX_API enables experimental smallocx API. */
 #undef JEMALLOC_EXPERIMENTAL_SMALLOCX_API
 
+/* JEMALLOC_EXPERIMENTAL_FASTPATH_PREFETCH enables prefetch
+ * on malloc fast path.
+ */
+#undef JEMALLOC_EXPERIMENTAL_FASTPATH_PREFETCH
+
 /* JEMALLOC_PROF enables allocation profiling. */
 #undef JEMALLOC_PROF
 
diff --git a/include/jemalloc/internal/jemalloc_internal_inlines_c.h b/include/jemalloc/internal/jemalloc_internal_inlines_c.h
index 2c61f8c4f..60f3b2b13 100644
--- a/include/jemalloc/internal/jemalloc_internal_inlines_c.h
+++ b/include/jemalloc/internal/jemalloc_internal_inlines_c.h
@@ -374,6 +374,12 @@ imalloc_fastpath(size_t size, void *(fallback_alloc)(size_t)) {
 	 */
 	ret = cache_bin_alloc_easy(bin, &tcache_success);
 	if (tcache_success) {
+#if __GNUC__ && defined(JEMALLOC_EXPERIMENTAL_FASTPATH_PREFETCH)
+		cache_bin_sz_t lb = (cache_bin_sz_t)(uintptr_t)bin->stack_head;
+		if(likely(lb != bin->low_bits_empty)) {
+			util_prefetch_write_range(*(bin->stack_head), usize);
+		}
+#endif
 		fastpath_success_finish(tsd, allocated_after, bin, ret);
 		return ret;
 	}
