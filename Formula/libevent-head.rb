class LibeventHead < Formula
  desc "Asynchronous event library"
  homepage "https://libevent.org/"
  head "https://github.com/libevent/libevent.git"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  # depends_on "openssl@1.1" => :build

  def install
    system "./autogen.sh"
    system "./configure", "--disable-dependency-tracking",
                          "--disable-debug-mode",
                          "--disable-openssl",
                          "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <event2/event.h>

      int main()
      {
        struct event_base *base;
        base = event_base_new();
        event_base_free(base);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-levent", "-o", "test"
    system "./test"
  end
end

