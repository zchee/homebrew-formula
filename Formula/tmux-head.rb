class TmuxHead < Formula
  desc "Terminal multiplexer"
  homepage "https://tmux.github.io/"
  license "ISC"
  head "https://github.com/tmux/tmux.git", branch: "master"

  livecheck do
    url "https://github.com/tmux/tmux/releases/latest"
    regex(%r{href=.*?/tag/v?(\d+(?:\.\d+)+[a-z]?)["' >]}i)
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build

  depends_on "bison" => :build
  depends_on "libevent-head" => :build
  depends_on "ncurses-head" => :build
  depends_on "pcre" => :build
  depends_on "utf8proc-head" => :build

  resource "completion" do
    url "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux"
    sha256 "b5f7bbd78f9790026bbff16fc6e3fe4070d067f58f943e156bd1a8c3c99f6a6f"
  end

  patch :DATA

  def install
    cflags = "-march=native -Ofast -flto -std=c2x -Wno-pointer-sign"
    ldflags = "-march=native -Ofast -flto -lresolv"

    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags

    ENV["LIBEVENT_CORE_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_CORE_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent_core.a"
    ENV["LIBEVENT_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent_core.a"
    ENV["LIBNCURSES_CFLAGS"] = "-I#{Formula["ncurses-head"].opt_include}"
    ENV["LIBNCURSES_LIBS"] = "#{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    ENV["LIBNCURSESW_CFLAGS"] = "-I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV["LIBNCURSESW_LIBS"] = "#{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    ENV["LIBUTF8PROC_CFLAGS"] = "-I#{Formula["utf8proc-head"].opt_include}"
    ENV["LIBUTF8PROC_LIBS"] = "#{Formula["utf8proc-head"].opt_lib}/libutf8proc.a"

    inreplace "configure.ac", /AC_INIT\(\[tmux\],[^)]*\)/, "AC_INIT([tmux], master)"

    system "sh", "autogen.sh"

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --sysconfdir=#{etc}
      --enable-utf8proc
    ]

    system "./configure", *args

    system "make", "install"

    pkgshare.install "example_tmux.conf"
    bash_completion.install resource("completion")
  end

  def caveats
    <<~EOS
      Example configuration has been installed to:
        #{opt_pkgshare}
    EOS
  end

  test do
    system "#{bin}/tmux", "-V"
  end
end

__END__
diff --git a/src/Makefile.in b/src/Makefile.in
diff --git a/compat/imsg.c b/compat/imsg.c
index 54ac7e566..674c89e2b 100644
--- a/compat/imsg.c
+++ b/compat/imsg.c
@@ -30,7 +30,7 @@
 
 int	 imsg_fd_overhead = 0;
 
-static int	 imsg_get_fd(struct imsgbuf *);
+int	 imsg_get_fd(struct imsgbuf *);
 
 void
 imsg_init(struct imsgbuf *ibuf, int fd)
@@ -266,7 +266,7 @@ imsg_free(struct imsg *imsg)
 	freezero(imsg->data, imsg->hdr.len - IMSG_HEADER_SIZE);
 }
 
-static int
+int
 imsg_get_fd(struct imsgbuf *ibuf)
 {
 	int		 fd;
diff --git a/compat/imsg.h b/compat/imsg.h
index 5b092cfcf..6d58d8ecd 100644
--- a/compat/imsg.h
+++ b/compat/imsg.h
@@ -107,6 +107,7 @@ struct ibuf *imsg_create(struct imsgbuf *, uint32_t, uint32_t, pid_t, uint16_t);
 int	 imsg_add(struct ibuf *, const void *, uint16_t);
 void	 imsg_close(struct imsgbuf *, struct ibuf *);
 void	 imsg_free(struct imsg *);
+int	 imsg_get_fd(struct imsgbuf *ibuf);
 int	 imsg_flush(struct imsgbuf *);
 void	 imsg_clear(struct imsgbuf *);
 
diff --git a/proc.c b/proc.c
index 68ab9604e..2914c2d36 100644
--- a/proc.c
+++ b/proc.c
@@ -32,6 +32,7 @@
 #endif
 
 #include "tmux.h"
+#include "compat/imsg.h"
 
 struct tmuxproc {
 	const char	 *name;
diff --git a/server-client.c b/server-client.c
index a74945032..301856a85 100644
--- a/server-client.c
+++ b/server-client.c
@@ -28,6 +28,7 @@
 #include <unistd.h>
 
 #include "tmux.h"
+#include "compat/imsg.h"
 
 static void	server_client_free(int, short, void *);
 static void	server_client_check_pane_resize(struct window_pane *);
