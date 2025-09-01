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
  depends_on "jemalloc-head"

  uses_from_macos "bison" => :build # for yacc

  # Old versions of macOS libc disagree with utf8proc character widths.
  # https://github.com/tmux/tmux/issues/2223
  on_system :linux, macos: :sierra_or_newer do
    depends_on "utf8proc-head"
  end

  resource "completion" do
    url "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/8da7f797245970659b259b85e5409f197b8afddd/completions/tmux"
    sha256 "4e2179053376f4194b342249d75c243c1573c82c185bfbea008be1739048e709"
  end

  patch :DATA

  def install
    system "sh", "autogen.sh" if build.head?

    args = %W[
      --enable-sixel
      --sysconfdir=#{etc}

      --enable-jemalloc
    ]

    # tmux finds the `tmux-256color` terminfo provided by our ncurses
    # and uses that as the default `TERM`, but this causes issues for
    # tools that link with the very old ncurses provided by macOS.
    # https://github.com/Homebrew/homebrew-core/issues/102748
    args << "--with-TERM=screen-256color" if OS.mac? && MacOS.version < :sonoma
    on_system :linux, macos: :sierra_or_newer do
      args << "--enable-utf8proc" if OS.linux? || MacOS.version >= :high_sierra
      ENV["LIBUTF8PROC_CFLAGS"] = "-I#{Formula["utf8proc-head"].opt_include}" if MacOS.version >= :high_sierra
      ENV["LIBUTF8PROC_LIBS"] = "#{Formula["utf8proc-head"].opt_lib}/libutf8proc.a" if MacOS.version >= :high_sierra
    end

    ENV["LIBEVENT_CORE_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_CORE_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent_core.a"
    ENV["LIBEVENT_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent.a"
    ENV["LIBNCURSES_CFLAGS"] = "-I#{Formula["ncurses-head"].opt_include} -I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV["LIBNCURSES_LIBS"] = "#{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    ENV["LIBNCURSESW_CFLAGS"] = "-I#{Formula["ncurses-head"].opt_include} -I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV["JEMALLOC_CFLAGS"] = "-I#{Formula["jemalloc-head"].opt_include}"
    ENV["JEMALLOC_LIBS"] = "#{Formula["jemalloc-head"].opt_lib}/libjemalloc.a"

    target_cpu_flags = Hardware::CPU.intel? ? "-march=x86-64-v4 -mtune=skylake-avx512" : "-march=native"
    cflags = "#{target_cpu_flags} -O3 -ffast-math -flto -std=c2x"
    ldflags = "#{target_cpu_flags} -O3 -ffast-math -lresolv"
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags

    system "./configure", *args, *std_configure_args

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
diff --git a/server-client.c b/server-client.c
index b3af0314..8e670869 100644
--- a/server-client.c
+++ b/server-client.c
@@ -3354,7 +3354,7 @@ server_client_dispatch(struct imsg *imsg, void *arg)
 			break;
 		server_client_update_latest(c);
 		tty_resize(&c->tty);
-		tty_repeat_requests(&c->tty, 0);
+		tty_repeat_requests(&c->tty);
 		recalculate_sizes();
 		if (c->overlay_resize == NULL)
 			server_client_clear_overlay(c);
@@ -3959,5 +3959,5 @@ server_client_report_theme(struct client *c, enum client_theme theme)
 	 * Request foreground and background colour again. Don't forward 2031 to
 	 * panes until a response is received.
 	 */
-	tty_repeat_requests(&c->tty, 1);
+	tty_puts(&c->tty, "\033]10;?\033\\\033]11;?\033\\");
 }
diff --git a/tmux.h b/tmux.h
index 4276ce8b..ec7bde24 100644
--- a/tmux.h
+++ b/tmux.h
@@ -1577,10 +1577,10 @@ struct tty {
 #define TTY_SYNCING 0x400
 #define TTY_HAVEDA2 0x800
 #define TTY_WINSIZEQUERY 0x1000
-#define TTY_WAITFG 0x2000
-#define TTY_WAITBG 0x4000
+#define TTY_HAVEFG 0x2000
+#define TTY_HAVEBG 0x4000
 #define TTY_ALL_REQUEST_FLAGS \
-	(TTY_HAVEDA|TTY_HAVEDA2|TTY_HAVEXDA)
+	(TTY_HAVEDA|TTY_HAVEDA2|TTY_HAVEXDA|TTY_HAVEFG|TTY_HAVEBG)
 	int		 flags;
 
 	struct tty_term	*term;
@@ -2508,7 +2508,7 @@ void	tty_set_size(struct tty *, u_int, u_int, u_int, u_int);
 void	tty_invalidate(struct tty *);
 void	tty_start_tty(struct tty *);
 void	tty_send_requests(struct tty *);
-void	tty_repeat_requests(struct tty *, int);
+void	tty_repeat_requests(struct tty *);
 void	tty_stop_tty(struct tty *);
 void	tty_set_title(struct tty *, const char *);
 void	tty_set_path(struct tty *, const char *);
diff --git a/tty-keys.c b/tty-keys.c
index a367d022..267b5379 100644
--- a/tty-keys.c
+++ b/tty-keys.c
@@ -937,8 +937,7 @@ partial_key:
 	delay = options_get_number(global_options, "escape-time");
 	if (delay == 0)
 		delay = 1;
-	if ((tty->flags & (TTY_WAITFG|TTY_WAITBG) ||
-	    (tty->flags & TTY_ALL_REQUEST_FLAGS) != TTY_ALL_REQUEST_FLAGS)) {
+	if ((tty->flags & TTY_ALL_REQUEST_FLAGS) != TTY_ALL_REQUEST_FLAGS) {
 		log_debug("%s: increasing delay for active query", c->name);
 		if (delay < 500)
 			delay = 500;
@@ -1687,14 +1686,14 @@ tty_keys_colours(struct tty *tty, const char *buf, size_t len, size_t *size,
 		else
 			log_debug("fg is %s", colour_tostring(n));
 		*fg = n;
-		tty->flags &= ~TTY_WAITFG;
+		tty->flags |= TTY_HAVEFG;
 	} else if (n != -1) {
 		if (c != NULL)
 			log_debug("%s bg is %s", c->name, colour_tostring(n));
 		else
 			log_debug("bg is %s", colour_tostring(n));
 		*bg = n;
-		tty->flags &= ~TTY_WAITBG;
+		tty->flags |= TTY_HAVEBG;
 	}
 
 	return (0);
diff --git a/tty.c b/tty.c
index 58254bc1..19e55757 100644
--- a/tty.c
+++ b/tty.c
@@ -44,11 +44,11 @@ static void	tty_cursor_pane_unless_wrap(struct tty *,
 		    const struct tty_ctx *, u_int, u_int);
 static void	tty_colours(struct tty *, const struct grid_cell *);
 static void	tty_check_fg(struct tty *, struct colour_palette *,
-		    struct grid_cell *);
+    		    struct grid_cell *);
 static void	tty_check_bg(struct tty *, struct colour_palette *,
-		    struct grid_cell *);
+    		    struct grid_cell *);
 static void	tty_check_us(struct tty *, struct colour_palette *,
-		    struct grid_cell *);
+    		    struct grid_cell *);
 static void	tty_colours_fg(struct tty *, const struct grid_cell *);
 static void	tty_colours_bg(struct tty *, const struct grid_cell *);
 static void	tty_colours_us(struct tty *, const struct grid_cell *);
@@ -311,23 +311,9 @@ tty_start_timer_callback(__unused int fd, __unused short events, void *data)
 	struct client	*c = tty->client;
 
 	log_debug("%s: start timer fired", c->name);
-
 	if ((tty->flags & (TTY_HAVEDA|TTY_HAVEDA2|TTY_HAVEXDA)) == 0)
 		tty_update_features(tty);
 	tty->flags |= TTY_ALL_REQUEST_FLAGS;
-
-	tty->flags &= ~(TTY_WAITBG|TTY_WAITFG);
-}
-
-static void
-tty_start_start_timer(struct tty *tty)
-{
-	struct client	*c = tty->client;
-	struct timeval	 tv = { .tv_sec = TTY_QUERY_TIMEOUT };
-
-	log_debug("%s: start timer started", c->name);
-	evtimer_set(&tty->start_timer, tty_start_timer_callback, tty);
-	evtimer_add(&tty->start_timer, &tv);
 }
 
 void
@@ -335,6 +321,7 @@ tty_start_tty(struct tty *tty)
 {
 	struct client	*c = tty->client;
 	struct termios	 tio;
+	struct timeval	 tv = { .tv_sec = TTY_QUERY_TIMEOUT };
 
 	setblocking(c->fd, 0);
 	event_add(&tty->event_in, NULL);
@@ -374,7 +361,8 @@ tty_start_tty(struct tty *tty)
 		tty_puts(tty, "\033[?2031h\033[?996n");
 	}
 
-	tty_start_start_timer(tty);
+	evtimer_set(&tty->start_timer, tty_start_timer_callback, tty);
+	evtimer_add(&tty->start_timer, &tv);
 
 	tty->flags |= TTY_STARTED;
 	tty_invalidate(tty);
@@ -400,35 +388,29 @@ tty_send_requests(struct tty *tty)
 			tty_puts(tty, "\033[>c");
 		if (~tty->flags & TTY_HAVEXDA)
 			tty_puts(tty, "\033[>q");
-		tty_puts(tty, "\033]10;?\033\\\033]11;?\033\\");
-		tty->flags |= (TTY_WAITBG|TTY_WAITFG);
+		tty_puts(tty, "\033]10;?\033\\");
+		tty_puts(tty, "\033]11;?\033\\");
 	} else
 		tty->flags |= TTY_ALL_REQUEST_FLAGS;
 	tty->last_requests = time(NULL);
 }
 
 void
-tty_repeat_requests(struct tty *tty, int force)
+tty_repeat_requests(struct tty *tty)
 {
-	struct client	*c = tty->client;
 	time_t	t = time(NULL);
-	u_int	n = t - tty->last_requests;
 
 	if (~tty->flags & TTY_STARTED)
 		return;
 
-	if (!force && n <= TTY_REQUEST_LIMIT) {
-		log_debug("%s: not repeating requests (%u seconds)", c->name, n);
+	if (t - tty->last_requests <= TTY_REQUEST_LIMIT)
 		return;
-	}
-	log_debug("%s: %srepeating requests (%u seconds)", c->name, force ? "(force) " : "" , n);
 	tty->last_requests = t;
 
 	if (tty->term->flags & TERM_VT100LIKE) {
-		tty_puts(tty, "\033]10;?\033\\\033]11;?\033\\");
-	tty->flags |= (TTY_WAITBG|TTY_WAITFG);
-    }
-    tty_start_start_timer(tty);
+		tty_puts(tty, "\033]10;?\033\\");
+		tty_puts(tty, "\033]11;?\033\\");
+	}
 }
 
 void
@@ -1718,7 +1700,7 @@ tty_sync_end(struct tty *tty)
 	tty->flags &= ~TTY_SYNCING;
 
 	if (tty_term_has(tty->term, TTYC_SYNC)) {
-		log_debug("%s sync end", tty->client->name);
+ 		log_debug("%s sync end", tty->client->name);
 		tty_putcode_i(tty, TTYC_SYNC, 2);
 	}
 }
