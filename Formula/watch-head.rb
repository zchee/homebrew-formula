class WatchHead < Formula
  desc "Executes a program periodically, showing output fullscreen"
  homepage "https://gitlab.com/procps-ng/procps"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.1-or-later"]
  head "https://gitlab.com/procps-ng/procps.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gettext" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build

  depends_on "ncurses-head" => :build
  depends_on "libiconv" => :build

  conflicts_with "visionmedia-watch"

  patch :DATA

  def install
    system "autoreconf", "-fiv"
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--disable-nls",
                          "--enable-watch8bit"
    system "make", "src/watch"
    bin.install "src/watch"
    man1.install "man/watch.1"
  end

  test do
    system bin/"watch", "--errexit", "--chgexit", "--interval", "1", "date"
  end
end

__END__
diff --git a/local/signals.c b/local/signals.c
index 6d68c07d..1c878328 100644
--- a/local/signals.c
+++ b/local/signals.c
@@ -83,6 +83,10 @@ typedef struct mapstruct {
   int num;
 } mapstruct;
 
+#ifdef __APPLE__
+#define SIGPOLL 0
+#endif
+
 // Rank the more common names higher up the list to prioritize them in number-
 // -to-name lookups.
 static const mapstruct sigtable[] = {
