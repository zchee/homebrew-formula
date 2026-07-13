class TmuxHead < Formula
  desc "Terminal multiplexer"
  homepage "https://tmux.github.io/"
  license "ISC"

  livecheck do
    url :stable
    regex(/v?(\d+(?:\.\d+)+[a-z]?)/i)
    strategy :github_latest
  end

  head do
    url "https://github.com/tmux/tmux.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "pkgconf" => :build
  depends_on "libevent-head"
  depends_on "ncurses-head"
  depends_on "utf8proc-head"

  uses_from_macos "bison" => :build # for yacc

  patch :DATA

  def install
    system "sh", "autogen.sh" if build.head?

    args = %W[
      --disable-debug
      --disable-asan
      --with-TERM=tmux-256color
      --enable-sixel
      --sysconfdir=#{etc}
      --enable-utf8proc=#{Formula["utf8proc-head"].opt_prefix}
    ]

    ENV["LIBEVENT_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_CORE_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_CORE_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent_core.a"
    ENV["LIBEVENT_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent.a"
    ENV["LIBNCURSESW_CFLAGS"] = "-I#{Formula["ncurses-head"].opt_include} -I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV["LIBNCURSESW_LIBS"] = "#{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    ENV["LIBUTF8PROC_CFLAGS"] = "-I#{Formula["utf8proc-head"].opt_include}"
    ENV["LIBUTF8PROC_LIBS"] = "#{Formula["utf8proc-head"].opt_lib}/libutf8proc.a"

    if Hardware::CPU.intel?
      cflags  = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x -DNDEBUG"
      ldflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    else
      cpu = `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`.chomp
      cflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x -DNDEBUG"
      ldflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -lresolv"
    end
    cppflags = "-DNDEBUG"
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags
    ENV.append "CPPFLAGS", *cppflags

    system "./configure", *args, *std_configure_args
    system "make", "install"

    pkgshare.install "example_tmux.conf"
  end

  def caveats
    <<~EOS
      Example configuration has been installed to:
        #{opt_pkgshare}
    EOS
  end

  test do
    system bin/"tmux", "-V"

    require "pty"

    socket = testpath/tap.user
    PTY.spawn bin/"tmux", "-S", socket, "-f", File::NULL
    sleep 10

    assert_path_exists socket
    assert_predicate socket, :socket?
    assert_equal "no server running on #{socket}", shell_output("#{bin}/tmux -S#{socket} list-sessions 2>&1", 1).chomp
  end
end

__END__
diff --git a/input.c b/input.c
index a85b555f..080c35ad 100644
--- a/input.c
+++ b/input.c
@@ -1688,6 +1688,9 @@ input_csi_dispatch(struct input_ctx *ictx)
 		case 2031:	/* theme update notifications */
 			n = (s->mode & MODE_THEME_UPDATES) ? 1 : 2;
 			break;
+		case 2048:	/* in-band resize reports */
+			n = (s->mode & MODE_RESIZE_REPORT) ? 1 : 2;
+			break;
 		default:
 			n = 0;
 			break;
@@ -1956,6 +1959,9 @@ input_csi_dispatch_rm_private(struct input_ctx *ictx)
 		case 2026:
 			screen_write_stop_sync(ictx->wp);
 			break;
+		case 2048:
+			screen_write_mode_clear(sctx, MODE_RESIZE_REPORT);
+			break;
 		case 2031:
 			screen_write_mode_clear(sctx, MODE_THEME_UPDATES);
 			if (ictx->wp != NULL)
@@ -2066,6 +2072,13 @@ input_csi_dispatch_sm_private(struct input_ctx *ictx)
 		case 2026:
 			screen_write_start_sync(ictx->wp);
 			break;
+		case 2048:
+			screen_write_mode_set(sctx, MODE_RESIZE_REPORT);
+			if (ictx->wp != NULL) {
+				window_pane_send_resize_report(ictx->wp,
+				    ictx->wp->sx, ictx->wp->sy);
+			}
+			break;
 		default:
 			log_debug("%s: unknown '%c'", __func__, ictx->ch);
 			break;
diff --git a/screen.c b/screen.c
index 62a07927..41d4e307 100644
--- a/screen.c
+++ b/screen.c
@@ -829,6 +829,8 @@ screen_mode_to_string(int mode)
 		strlcat(tmp, "THEME_UPDATES,", sizeof tmp);
 	if (mode & MODE_SYNC)
 		strlcat(tmp, "SYNC,", sizeof tmp);
+	if (mode & MODE_RESIZE_REPORT)
+		strlcat(tmp, "RESIZE_REPORT,", sizeof tmp);
 	if (*tmp != '\0')
 		tmp[strlen(tmp) - 1] = '\0';
 	return (tmp);
diff --git a/tmux.h b/tmux.h
index db46e6fb..c606e895 100644
--- a/tmux.h
+++ b/tmux.h
@@ -687,6 +687,7 @@ enum tty_code_code {
 #define MODE_KEYS_EXTENDED_2 0x40000
 #define MODE_THEME_UPDATES 0x80000
 #define MODE_SYNC 0x100000
+#define MODE_RESIZE_REPORT 0x200000
 
 #define ALL_MODES 0xffffff
 #define ALL_MOUSE_MODES (MODE_MOUSE_STANDARD|MODE_MOUSE_BUTTON|MODE_MOUSE_ALL)
@@ -3688,6 +3689,8 @@ int		 window_pane_get_bg_control_client(struct window_pane *);
 int		 window_get_bg_client(struct window_pane *);
 enum client_theme window_pane_get_theme(struct window_pane *);
 void		 window_pane_send_theme_update(struct window_pane *);
+void		 window_pane_send_resize_report(struct window_pane *, u_int,
+		     u_int);
 enum pane_lines	 window_pane_get_pane_lines(struct window_pane *);
 enum pane_lines	 window_get_pane_lines(struct window *);
 int		 window_get_pane_status(struct window *);
diff --git a/window.c b/window.c
index 29849160..ee4489e2 100644
--- a/window.c
+++ b/window.c
@@ -500,6 +500,32 @@ window_pane_send_resize(struct window_pane *wp, u_int sx, u_int sy)
 		if (errno != EINVAL && errno != ENXIO)
 #endif
 		fatal("ioctl failed");
+	window_pane_send_resize_report(wp, sx, sy);
+}
+
+/*
+ * Send an in-band resize report (DECSET 2048) to the pane. The report pairs
+ * with the TIOCSWINSZ ioctl so applications that enable the mode see resizes
+ * as ordered escape sequences on their input instead of only SIGWINCH.
+ */
+void
+window_pane_send_resize_report(struct window_pane *wp, u_int sx, u_int sy)
+{
+	struct window	*w;
+	char		 buf[64];
+	int		 len;
+
+	if (wp == NULL || window_pane_exited(wp))
+		return;
+	if (~wp->screen->mode & MODE_RESIZE_REPORT)
+		return;
+	w = wp->window;
+
+	len = xsnprintf(buf, sizeof buf, "\033[48;%u;%u;%u;%ut", sy, sx,
+	    sy * w->ypixel, sx * w->xpixel);
+	if (len > 0)
+		bufferevent_write(wp->event, buf, len);
+	log_debug("%s: %%%u %ux%u", __func__, wp->id, sx, sy);
 }
 
 int
