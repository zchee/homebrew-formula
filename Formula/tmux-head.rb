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
      --enable-utf8proc=#{formula_opt_prefix("utf8proc-head")}
    ]

    ENV["LIBEVENT_CFLAGS"] = "-I#{formula_opt_include("libevent-head")}"
    ENV["LIBEVENT_CORE_CFLAGS"] = "-I#{formula_opt_include("libevent-head")}"
    ENV["LIBEVENT_CORE_LIBS"] = "#{formula_opt_lib("libevent-head")}/libevent_core.a"
    ENV["LIBEVENT_LIBS"] = "#{formula_opt_lib("libevent-head")}/libevent.a"
    ENV["LIBNCURSESW_CFLAGS"] = "-I#{formula_opt_include("ncurses-head")} -I#{formula_opt_include("ncurses-head")}/ncursesw"
    ENV["LIBNCURSESW_LIBS"] = "#{formula_opt_lib("ncurses-head")}/libncursesw.a"
    ENV["LIBUTF8PROC_CFLAGS"] = "-I#{formula_opt_include("utf8proc-head")}"
    ENV["LIBUTF8PROC_LIBS"] = "#{formula_opt_lib("utf8proc-head")}/libutf8proc.a"

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
diff --git a/compat.h b/compat.h
index 66a22640..6da50747 100644
--- a/compat.h
+++ b/compat.h
@@ -453,6 +453,7 @@ int		 systemd_move_to_new_cgroup(char **);
 int		 utf8proc_wcwidth(wchar_t);
 int		 utf8proc_mbtowc(wchar_t *, const char *, size_t);
 int		 utf8proc_wctomb(char *, wchar_t);
+int		 utf8proc_grapheme_breakable(const char *, size_t, wchar_t);
 #endif
 
 #ifdef NEED_FUZZING
diff --git a/compat/utf8proc.c b/compat/utf8proc.c
index 147da696..1e02aa85 100644
--- a/compat/utf8proc.c
+++ b/compat/utf8proc.c
@@ -64,3 +64,31 @@ utf8proc_wctomb(char *s, wchar_t wc)
 		return (-1);
 	return (utf8proc_encode_char(wc, s));
 }
+
+/*
+ * Is a grapheme cluster break permitted between the last codepoint of buf and
+ * next? Break state is replayed across the whole buffer so that stateful
+ * rules such as GB9c (Indic conjuncts) and GB11 (emoji ZWJ) apply.
+ */
+int
+utf8proc_grapheme_breakable(const char *buf, size_t len, wchar_t next)
+{
+	utf8proc_int32_t	state = 0, cp, last = -1;
+	utf8proc_ssize_t	off = 0, n;
+
+	while (off < (utf8proc_ssize_t)len) {
+		n = utf8proc_iterate((const utf8proc_uint8_t *)buf + off,
+		    len - off, &cp);
+		if (n <= 0 || cp < 0)
+			return (1);
+		if (last >= 0)
+			(void)utf8proc_grapheme_break_stateful(last, cp,
+			    &state);
+		last = cp;
+		off += n;
+	}
+	if (last < 0)
+		return (1);
+	return (utf8proc_grapheme_break_stateful(last,
+	    (utf8proc_int32_t)next, &state));
+}
diff --git a/grid-view.c b/grid-view.c
index 86317526..e29a285d 100644
--- a/grid-view.c
+++ b/grid-view.c
@@ -133,6 +133,51 @@ grid_view_scroll_region_down(struct grid *gd, u_int rupper, u_int rlower,
 	grid_move_lines(gd, rupper + 1, rupper, rlower - rupper, bg);
 }
 
+/*
+ * Scroll a rectangular region bounded by both a vertical [rupper, rlower] and a
+ * horizontal [left, right] range. Used when left-right margins are active: only
+ * the cells inside the column range move, and the region never scrolls into
+ * history (matching xterm, where a margined scroll stays on screen). "up"
+ * selects the direction; "n" is the number of lines.
+ */
+void
+grid_view_scroll_pad_region(struct grid *gd, u_int rupper, u_int rlower,
+    u_int left, u_int right, int up, u_int n, u_int bg)
+{
+	struct grid_cell	 gc;
+	u_int			 nx, y, x, src;
+
+	if (n == 0 || rupper > rlower || left > right)
+		return;
+	if (n > rlower - rupper + 1)
+		n = rlower - rupper + 1;
+	nx = right + 1 - left;
+
+	if (up) {
+		/* Move each row up by n, top to bottom. */
+		for (y = rupper; y + n <= rlower; y++) {
+			src = y + n;
+			for (x = left; x <= right; x++) {
+				grid_view_get_cell(gd, x, src, &gc);
+				grid_view_set_cell(gd, x, y, &gc);
+			}
+		}
+		/* Clear the freed rows at the bottom of the region. */
+		grid_view_clear(gd, left, rlower + 1 - n, nx, n, bg);
+	} else {
+		/* Move each row down by n, bottom to top. */
+		for (y = rlower + 1; y-- > rupper + n;) {
+			src = y - n;
+			for (x = left; x <= right; x++) {
+				grid_view_get_cell(gd, x, src, &gc);
+				grid_view_set_cell(gd, x, y, &gc);
+			}
+		}
+		/* Clear the freed rows at the top of the region. */
+		grid_view_clear(gd, left, rupper, nx, n, bg);
+	}
+}
+
 /* Insert lines. */
 void
 grid_view_insert_lines(struct grid *gd, u_int py, u_int ny, u_int bg)
@@ -209,6 +254,112 @@ grid_view_insert_cells(struct grid *gd, u_int px, u_int py, u_int nx, u_int bg)
 		grid_move_cells(gd, px + nx, px, py, sx - px - nx, bg);
 }
 
+/*
+ * Blank a wide-character cell that has been split by a horizontal margin: a
+ * leading cell whose padding would fall at or past px, or a padding cell whose
+ * leading half is at or before px - 1 (i.e. the split runs across px).
+ */
+static void
+grid_view_clear_split(struct grid *gd, u_int px, u_int py, u_int bg)
+{
+	struct grid_cell	gc;
+
+	if (px == 0 || px >= gd->sx)
+		return;
+	grid_get_cell(gd, px, py, &gc);
+	if (gc.flags & GRID_FLAG_PADDING) {
+		/* Padding whose lead is to the left of the boundary. */
+		grid_clear(gd, px - 1, py, 2, 1, bg);
+		return;
+	}
+	grid_get_cell(gd, px - 1, py, &gc);
+	if (gc.data.width > 1) {
+		/* Wide lead whose padding is to the right of the boundary. */
+		grid_clear(gd, px - 1, py, 2, 1, bg);
+	}
+}
+
+/*
+ * Blank a wide-character lead left dangling against a right margin: its cell is
+ * at rx - 1 and its padding would have fallen at rx, outside the margin, so
+ * only the lead is cleared (rx itself holds protected out-of-margin content).
+ */
+static void
+grid_view_clear_margin_lead(struct grid *gd, u_int rx, u_int py, u_int bg)
+{
+	struct grid_cell	gc;
+
+	if (rx == 0)
+		return;
+	grid_get_cell(gd, rx - 1, py, &gc);
+	if (gc.data.width > 1)
+		grid_clear(gd, rx - 1, py, 1, 1, bg);
+}
+
+/*
+ * Blank a wide-character orphan exposed at a shift point (px): either a padding
+ * cell whose lead was consumed by the shift (clear px), or a lead at px - 1
+ * whose padding was overwritten (clear px - 1, but never left of the left
+ * margin so out-of-margin content is preserved). Both conditions are checked
+ * independently because a single delete can orphan a padding half of one
+ * character and the lead half of another.
+ *
+ * A wide character straddling a margin keeps its out-of-margin half (a lead at
+ * left - 1 or padding at the right margin) as a dangling half-cell; this
+ * matches plain DCH, which does no wide-character fixup, and self-heals on the
+ * next overwrite.
+ */
+static void
+grid_view_clear_shift_point(struct grid *gd, u_int px, u_int left, u_int py,
+    u_int bg)
+{
+	struct grid_cell	gc;
+
+	if (px >= gd->sx)
+		return;
+	grid_get_cell(gd, px, py, &gc);
+	if (gc.flags & GRID_FLAG_PADDING)
+		grid_clear(gd, px, py, 1, 1, bg);
+	if (px > left) {
+		grid_get_cell(gd, px - 1, py, &gc);
+		if (gc.data.width > 1)
+			grid_clear(gd, px - 1, py, 1, 1, bg);
+	}
+}
+
+/*
+ * Insert characters, bounded on the right by a margin. Cells from px to the
+ * right margin shift right by nx; cells that would move past the margin are
+ * dropped rather than pushed off the screen.
+ */
+void
+grid_view_insert_cells_right(struct grid *gd, u_int px, u_int py, u_int nx,
+    u_int right, u_int bg)
+{
+	u_int	rx;
+
+	px = grid_view_x(gd, px);
+	py = grid_view_y(gd, py);
+	rx = grid_view_x(gd, right) + 1;	/* one past the right margin */
+
+	if (px >= rx)
+		return;
+	if (nx > rx - px)
+		nx = rx - px;
+	if (px + nx >= rx)
+		grid_clear(gd, px, py, rx - px, 1, bg);
+	else
+		grid_move_cells(gd, px + nx, px, py, rx - px - nx, bg);
+	/* Clear the gap opened at the cursor. */
+	grid_clear(gd, px, py, nx, 1, bg);
+	/*
+	 * The shift can leave a wide character split at the end of the moved
+	 * run or dangling against the right margin; blank either orphan.
+	 */
+	grid_view_clear_split(gd, px + nx, py, bg);
+	grid_view_clear_margin_lead(gd, rx, py, bg);
+}
+
 /* Delete characters. */
 void
 grid_view_delete_cells(struct grid *gd, u_int px, u_int py, u_int nx, u_int bg)
@@ -224,6 +375,38 @@ grid_view_delete_cells(struct grid *gd, u_int px, u_int py, u_int nx, u_int bg)
 	grid_clear(gd, sx - nx, py, nx, 1, bg);
 }
 
+/*
+ * Delete characters, bounded on the right by a margin. Cells from px+nx to the
+ * right margin shift left by nx; the nx cells that open up against the margin
+ * are cleared.
+ */
+void
+grid_view_delete_cells_right(struct grid *gd, u_int px, u_int py, u_int nx,
+    u_int left, u_int right, u_int bg)
+{
+	u_int	lx, rx;
+
+	px = grid_view_x(gd, px);
+	py = grid_view_y(gd, py);
+	lx = grid_view_x(gd, left);
+	rx = grid_view_x(gd, right) + 1;	/* one past the right margin */
+
+	if (px >= rx)
+		return;
+	if (nx > rx - px)
+		nx = rx - px;
+	grid_move_cells(gd, px, px + nx, py, rx - px - nx, bg);
+	grid_clear(gd, rx - nx, py, nx, 1, bg);
+	/*
+	 * The shift can leave a wide character orphan at the deletion point (a
+	 * dangling lead or shifted-in padding) or at the boundary of the
+	 * cleared region; blank either without disturbing content outside the
+	 * left margin.
+	 */
+	grid_view_clear_shift_point(gd, px, lx, py, bg);
+	grid_view_clear_shift_point(gd, rx - nx, lx, py, bg);
+}
+
 /* Convert cells into a string. */
 char *
 grid_view_string_cells(struct grid *gd, u_int px, u_int py, u_int nx)
diff --git a/input.c b/input.c
index 0aac9bfb..b71dd9f3 100644
--- a/input.c
+++ b/input.c
@@ -1308,7 +1308,7 @@ input_c0_dispatch(struct input_ctx *ictx)
 	struct window_pane	*wp = ictx->wp;
 	struct screen		*s = sctx->s;
 	struct grid_cell	 gc, first_gc;
-	u_int			 cx, line;
+	u_int			 cx, line, tabstop;
 	u_int			 width;
 	int			 has_content = 0;
 
@@ -1329,9 +1329,16 @@ input_c0_dispatch(struct input_ctx *ictx)
 		screen_write_backspace(sctx);
 		break;
 	case '\011':	/* HT */
-		/* Don't tab beyond the end of the line. */
+		/*
+		 * Don't tab beyond the end of the line, or beyond the right
+		 * margin when left-right margin mode is active.
+		 */
 		cx = s->cx;
-		if (cx >= screen_size_x(s) - 1)
+		if (s->mode & MODE_LEFT_RIGHT_MARGIN)
+			tabstop = s->rright;
+		else
+			tabstop = screen_size_x(s) - 1;
+		if (cx >= tabstop)
 			break;
 
 		/* Find the next tab point, or use the last column if none. */
@@ -1348,7 +1355,7 @@ input_c0_dispatch(struct input_ctx *ictx)
 			cx++;
 			if (bit_test(s->tabs, cx))
 				break;
-		} while (cx < screen_size_x(s) - 1);
+		} while (cx < tabstop);
 
 		width = cx - s->cx;
 		if (has_content || width > sizeof gc.data.data)
@@ -1469,7 +1476,7 @@ input_csi_dispatch(struct input_ctx *ictx)
 	const struct input_table_entry	*entry;
 	struct options			*oo;
 	int				 i, n, m, ek, set, p;
-	u_int				 cx, bg = ictx->cell.cell.bg;
+	u_int				 cx, cbtfloor, bg = ictx->cell.cell.bg;
 
 	if (ictx->flags & INPUT_DISCARD)
 		return (0);
@@ -1493,13 +1500,21 @@ input_csi_dispatch(struct input_ctx *ictx)
 		cx = s->cx;
 		if (cx > screen_size_x(s) - 1)
 			cx = screen_size_x(s) - 1;
+		/*
+		 * Do not tab back past the left margin when left-right margin
+		 * mode is active and the cursor starts at or after it.
+		 */
+		if ((s->mode & MODE_LEFT_RIGHT_MARGIN) && cx >= s->rleft)
+			cbtfloor = s->rleft;
+		else
+			cbtfloor = 0;
 		n = input_get(ictx, 0, 1, 1);
 		if (n == -1)
 			break;
-		while (cx > 0 && n-- > 0) {
+		while (cx > cbtfloor && n-- > 0) {
 			do
 				cx--;
-			while (cx > 0 && !bit_test(s->tabs, cx));
+			while (cx > cbtfloor && !bit_test(s->tabs, cx));
 		}
 		s->cx = cx;
 		break;
@@ -1681,6 +1696,9 @@ input_csi_dispatch(struct input_ctx *ictx)
 		case 25:	/* DECTCEM */
 			n = (s->mode & MODE_CURSOR) ? 1 : 2;
 			break;
+		case 69:	/* DECLRMM: left/right margin mode */
+			n = (s->mode & MODE_LEFT_RIGHT_MARGIN) ? 1 : 2;
+			break;
 		case 47:
 		case 1047:
 		case 1049:	/* alternate screen */
@@ -1710,9 +1728,15 @@ input_csi_dispatch(struct input_ctx *ictx)
 		case 2026:	/* synchronized output */
 			n = (s->mode & MODE_SYNC) ? 1 : 2;
 			break;
+		case 2027:	/* grapheme cluster processing */
+			n = (s->mode & MODE_GRAPHEME_CLUSTERS) ? 1 : 2;
+			break;
 		case 2031:	/* theme update notifications */
 			n = (s->mode & MODE_THEME_UPDATES) ? 1 : 2;
 			break;
+		case 2048:	/* in-band resize reports */
+			n = (s->mode & MODE_RESIZE_REPORT) ? 1 : 2;
+			break;
 		default:
 			n = 0;
 			break;
@@ -1827,7 +1851,19 @@ input_csi_dispatch(struct input_ctx *ictx)
 		input_csi_dispatch_rm_private(ictx);
 		break;
 	case INPUT_CSI_SCP:
-		input_save_state(ictx);
+		/*
+		 * CSI s is DECSLRM (set left and right margins) when the
+		 * left-right margin mode (DECLRMM, ?69) is enabled and SCP
+		 * (save cursor) otherwise. xterm disambiguates purely on the
+		 * mode, never on the number of parameters.
+		 */
+		if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+			n = input_get(ictx, 0, 1, 1);
+			m = input_get(ictx, 1, 1, screen_size_x(s));
+			if (n != -1 && m != -1)
+				screen_write_setmargins(sctx, n - 1, m - 1);
+		} else
+			input_save_state(ictx);
 		break;
 	case INPUT_CSI_SGR:
 		input_csi_dispatch_sgr(ictx);
@@ -1925,6 +1961,7 @@ static void
 input_csi_dispatch_rm_private(struct input_ctx *ictx)
 {
 	struct screen_write_ctx	*sctx = &ictx->ctx;
+	struct screen		*s = sctx->s;
 	struct grid_cell	*gc = &ictx->cell.cell;
 	u_int			 i;
 
@@ -1936,6 +1973,7 @@ input_csi_dispatch_rm_private(struct input_ctx *ictx)
 			screen_write_mode_clear(sctx, MODE_KCURSOR);
 			break;
 		case 3:		/* DECCOLM */
+			screen_write_setmargins(sctx, 0, screen_size_x(s) - 1);
 			screen_write_cursormove(sctx, 0, 0, 1);
 			screen_write_clearscreen(sctx, gc->bg);
 			break;
@@ -1953,6 +1991,15 @@ input_csi_dispatch_rm_private(struct input_ctx *ictx)
 		case 25:	/* TCEM */
 			screen_write_mode_clear(sctx, MODE_CURSOR);
 			break;
+		case 69:	/* DECLRMM: left/right margin mode */
+			screen_write_mode_clear(sctx, MODE_LEFT_RIGHT_MARGIN);
+			/*
+			 * Resetting the mode also resets the margins, but unlike
+			 * DECSLRM it must not move the cursor.
+			 */
+			s->rleft = 0;
+			s->rright = screen_size_x(s) - 1;
+			break;
 		case 1000:
 		case 1001:
 		case 1002:
@@ -1981,6 +2028,12 @@ input_csi_dispatch_rm_private(struct input_ctx *ictx)
 		case 2026:
 			screen_write_stop_sync(ictx->wp);
 			break;
+		case 2027:
+			screen_write_mode_clear(sctx, MODE_GRAPHEME_CLUSTERS);
+			break;
+		case 2048:
+			screen_write_mode_clear(sctx, MODE_RESIZE_REPORT);
+			break;
 		case 2031:
 			screen_write_mode_clear(sctx, MODE_THEME_UPDATES);
 			if (ictx->wp != NULL)
@@ -2022,6 +2075,7 @@ static void
 input_csi_dispatch_sm_private(struct input_ctx *ictx)
 {
 	struct screen_write_ctx	*sctx = &ictx->ctx;
+	struct screen		*s = sctx->s;
 	struct grid_cell	*gc = &ictx->cell.cell;
 	u_int			 i;
 
@@ -2033,6 +2087,7 @@ input_csi_dispatch_sm_private(struct input_ctx *ictx)
 			screen_write_mode_set(sctx, MODE_KCURSOR);
 			break;
 		case 3:		/* DECCOLM */
+			screen_write_setmargins(sctx, 0, screen_size_x(s) - 1);
 			screen_write_cursormove(sctx, 0, 0, 1);
 			screen_write_clearscreen(sctx, ictx->cell.cell.bg);
 			break;
@@ -2050,6 +2105,9 @@ input_csi_dispatch_sm_private(struct input_ctx *ictx)
 		case 25:	/* TCEM */
 			screen_write_mode_set(sctx, MODE_CURSOR);
 			break;
+		case 69:	/* DECLRMM: left/right margin mode */
+			screen_write_mode_set(sctx, MODE_LEFT_RIGHT_MARGIN);
+			break;
 		case 1000:
 			screen_write_mode_clear(sctx, ALL_MOUSE_MODES);
 			screen_write_mode_set(sctx, MODE_MOUSE_STANDARD);
@@ -2091,6 +2149,16 @@ input_csi_dispatch_sm_private(struct input_ctx *ictx)
 		case 2026:
 			screen_write_start_sync(ictx->wp);
 			break;
+		case 2027:
+			screen_write_mode_set(sctx, MODE_GRAPHEME_CLUSTERS);
+			break;
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
diff --git a/regress/grapheme-cluster-mode.result b/regress/grapheme-cluster-mode.result
new file mode 100644
index 00000000..c922e62b
--- /dev/null
+++ b/regress/grapheme-cluster-mode.result
@@ -0,0 +1,6 @@
+A^[[?2027;2$y
+B^[[?2027;1$y
+C^[[?2027;2$y
+D^[[?2027;2$y
+E^[[1;2R
+F^[[1;3R
diff --git a/regress/grapheme-cluster-mode.sh b/regress/grapheme-cluster-mode.sh
new file mode 100644
index 00000000..b7989c4b
--- /dev/null
+++ b/regress/grapheme-cluster-mode.sh
@@ -0,0 +1,59 @@
+#!/bin/sh
+
+# Test DECSET 2027 (grapheme cluster processing): DECRQM reporting, reset on
+# RIS and VS16 forcing the previous character wide while the mode is set.
+# Only behaviour independent of utf8proc is asserted so the result is the
+# same whether or not tmux is built with it.
+
+PATH=/bin:/usr/bin
+TERM=screen
+
+[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
+TMUX="$TEST_TMUX -Ltest2027$$ -f/dev/null"
+$TMUX kill-server 2>/dev/null
+
+SCRIPT=$(mktemp)
+OUT=$(mktemp)
+trap "rm -f $SCRIPT $OUT" 0 1 15
+
+cat >$SCRIPT <<'EOF'
+OUT="$1"
+stty raw -echo min 0 time 10
+q() {
+	printf '\033[?2027$p'
+	printf '%s%s\n' "$1" "$(dd bs=64 count=1 2>/dev/null)" | cat -v >>"$OUT"
+}
+c() {
+	printf '\033[6n'
+	printf '%s%s\n' "$1" "$(dd bs=64 count=1 2>/dev/null)" | cat -v >>"$OUT"
+}
+q A
+printf '\033[?2027h'
+q B
+printf '\033[?2027l'
+q C
+printf '\033[?2027h'
+printf '\033c'
+q D
+printf '\033[?2027l'
+printf '\r\033[K\342\235\244\357\270\217'
+c E
+printf '\033[?2027h'
+printf '\r\033[K\342\235\244\357\270\217'
+c F
+EOF
+
+$TMUX new -d 'sleep 60' || exit 1
+$TMUX set -g variation-selector-always-wide off
+$TMUX neww -d "sh $SCRIPT $OUT"
+
+n=0
+while [ "$(wc -l <$OUT)" -lt 6 ] && [ $n -lt 15 ]; do
+	sleep 1
+	n=$((n + 1))
+done
+$TMUX kill-server 2>/dev/null
+
+cmp $OUT grapheme-cluster-mode.result || exit 1
+
+exit 0
diff --git a/regress/margins-mode.sh b/regress/margins-mode.sh
new file mode 100644
index 00000000..43b86e0b
--- /dev/null
+++ b/regress/margins-mode.sh
@@ -0,0 +1,337 @@
+#!/bin/sh
+
+# Test DECLRMM (private mode ?69) and DECSLRM (CSI Pl;Pr s) left/right
+# margins, plus the CSI s SCP/DECSLRM disambiguation.
+#
+# DECRQM (ESC[?69$p) should elicit DECRPM (ESC[?69;Ps$y) where Ps=1 when
+# MODE_LEFT_RIGHT_MARGIN is active and Ps=2 when reset. When ?69 is reset,
+# CSI s is SCP (save cursor); when ?69 is set, CSI Pl;Pr s sets margins.
+
+PATH=/bin:/usr/bin
+TERM=screen
+
+[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
+TMUX="$TEST_TMUX -Ltest69A$$ -f/dev/null"
+$TMUX kill-server 2>/dev/null
+sleep 1
+
+TMP=$(mktemp)
+trap "rm -f $TMP; $TMUX kill-server 2>/dev/null" 0 1 15
+
+$TMUX -f/dev/null new -d -x80 -y24 || exit 1
+sleep 1
+
+$TMUX set -g remain-on-exit on
+
+exit_status=0
+
+# query_decrpm <outfile> <mode> [setup_seq] <count>
+query_decrpm() {
+	_outfile=$1
+	_mode=$2
+	_setup=$3
+	_n=$4
+
+	$TMUX respawnw -k -t:0 -- sh -c "
+		exec 2>/dev/null
+		stty raw -echo
+		${_setup:+printf '$_setup'; sleep 0.2}
+		printf '\033[%s\$p' "$_mode"
+		dd bs=1 count=$_n 2>/dev/null | cat -v > $_outfile
+		sleep 0.2
+	" || exit 1
+	sleep 2
+}
+
+check() {
+	_label=$1
+	_expected=$2
+	_actual=$(cat "$TMP")
+	if [ "$_actual" = "$_expected" ]; then
+		[ -n "$VERBOSE" ] && echo "[PASS] $_label -> $_actual"
+	else
+		echo "[FAIL] $_label: expected '$_expected', got '$_actual'"
+		exit_status=1
+	fi
+}
+
+# The DECRPM reply "ESC[?69;Ps$y" is 9 bytes.
+# ------------------------------------------------------------------
+# Test 1: mode 69 reset by default (Ps=2)
+# ------------------------------------------------------------------
+query_decrpm "$TMP" "?69" '' 9
+check "DECRQM 69 (default/reset)" '^[[?69;2$y'
+
+# ------------------------------------------------------------------
+# Test 2: DECSET ?69, then query (expect Ps=1)
+# ------------------------------------------------------------------
+query_decrpm "$TMP" "?69" '\033[?69h' 9
+check "DECRQM 69 (set)" '^[[?69;1$y'
+
+# ------------------------------------------------------------------
+# Test 3: DECRST ?69, then query (expect Ps=2)
+# ------------------------------------------------------------------
+query_decrpm "$TMP" "?69" '\033[?69l' 9
+check "DECRQM 69 (reset)" '^[[?69;2$y'
+
+# ------------------------------------------------------------------
+# Test 4: SCP preserved when ?69 clear. Save cursor at row1 col6, move to
+# row1 col1, restore, then DSR 6n reports the restored position (1;6).
+# ------------------------------------------------------------------
+$TMUX respawnw -k -t:0 -- sh -c "
+	exec 2>/dev/null
+	stty raw -echo
+	printf '\033[1;6H\0337\033[1;1H\0338\033[6n'
+	dd bs=1 count=6 2>/dev/null | cat -v > $TMP
+	sleep 0.2
+" || exit 1
+sleep 2
+check "SCP preserved (mode clear)" '^[[1;6R'
+
+# ------------------------------------------------------------------
+# Test 5: DECSLRM active still leaves DECRQM ?69 set; bare CSI s (margin
+# reset) and CSI Pl;Pr s must not disturb the mode bit.
+# ------------------------------------------------------------------
+query_decrpm "$TMP" "?69" '\033[?69h\033[5;20s\033[s' 9
+check "DECRQM 69 (set, after DECSLRM + bare s)" '^[[?69;1$y'
+
+# check_capture <label> <printf-seq> <awk-condition-desc> <expected-line-2>
+# Runs a pane that emits the sequence, captures the top rows, and compares a
+# specific captured row (0-indexed) to an expected string.
+capture_row() {
+	_label=$1; _seq=$2; _row=$3; _expected=$4
+	# Keep the pane alive while capturing; a pane that exits clears its
+	# screen before capture-pane can read it.
+	$TMUX respawnw -k -t:0 -- sh -c "
+		exec 2>/dev/null
+		stty raw -echo
+		printf '$_seq'
+		sleep 10
+	" || exit 1
+	sleep 1.5
+	_actual=$($TMUX capturep -p -t:0 | sed -n "$((_row + 1))p")
+	if [ "$_actual" = "$_expected" ]; then
+		[ -n "$VERBOSE" ] && echo "[PASS] $_label -> '$_actual'"
+	else
+		echo "[FAIL] $_label: expected '$_expected', got '$_actual'"
+		exit_status=1
+	fi
+}
+
+# ------------------------------------------------------------------
+# Test 6: autowrap to left margin. Margins columns 3..8 (1-based), cursor to
+# the left margin, print 10 letters. With wrapping they occupy [3..8] on row
+# 1 then wrap to [3..8] on row 2 (col 1-2 stay blank).
+#   ESC[2J clear, ESC[H home, ESC[?69h, ESC[3;8s margins, ESC[1;3H to (r1,c3)
+# Row 0 should be "  ABCDEF" (2 leading spaces, then 6 chars to col 8).
+# ------------------------------------------------------------------
+capture_row "wrap within margins (row0)" \
+	'\033[2J\033[H\033[?69h\033[3;8s\033[1;3HABCDEFGHIJ' \
+	0 '  ABCDEF'
+
+# Row 1 should be "  GHIJ" (wrapped remainder starting at left margin col 3).
+capture_row "wrap within margins (row1)" \
+	'\033[2J\033[H\033[?69h\033[3;8s\033[1;3HABCDEFGHIJ' \
+	1 '  GHIJ'
+
+# ------------------------------------------------------------------
+# Test 7: carriage return returns to the left margin. After setting margins
+# 3..8 and printing from col 3, a CR then 'Z' overwrites the left margin cell.
+#   Print ABC (cols 3,4,5), CR, Z -> col 3 becomes Z: "  ZBC"
+# ------------------------------------------------------------------
+capture_row "CR to left margin" \
+	'\033[2J\033[H\033[?69h\033[3;8s\033[1;3HABC\rZ' \
+	0 '  ZBC'
+
+# ------------------------------------------------------------------
+# Test 8: bounded editing operations. Margins are columns 3..8 (1-based),
+# i.e. left margin index 2 and right margin index 7. Each op must leave the
+# columns OUTSIDE [3..8] untouched while the inside scrolls or shifts.
+#
+# Shared fill (before enabling margins so the outer columns are painted):
+#   row1 aaaaaaaaaaaa, row2 bbbbbbbbbbbb, row3 cccccccccccc, row4 dddddddddddd
+# Then ESC[?69h ESC[3;8s enables margins 3..8.
+# ------------------------------------------------------------------
+FILL='\033[2J\033[Haaaaaaaaaaaa\r\nbbbbbbbbbbbb\r\ncccccccccccc\r\ndddddddddddd\033[?69h\033[3;8s'
+
+# DL 1 at row2 col3: the sub-rectangle [row2..bottom]x[cols3..8] scrolls up.
+# Row2 outer columns "bb....bbbb" stay; inner becomes row3's inner "cccccc".
+capture_row "DL within margins keeps outer (row1)" \
+	"$FILL"'\033[2;3H\033[M' 0 'aaaaaaaaaaaa'
+capture_row "DL within margins scrolls inner (row2)" \
+	"$FILL"'\033[2;3H\033[M' 1 'bbccccccbbbb'
+capture_row "DL within margins pads bottom row inner" \
+	"$FILL"'\033[2;3H\033[M' 2 'ccddddddcccc'
+
+# IL 1 at row2 col3: the sub-rectangle scrolls down; row2 inner is blanked,
+# outer columns untouched.
+capture_row "IL within margins blanks inner (row2)" \
+	"$FILL"'\033[2;3H\033[L' 1 'bb      bbbb'
+capture_row "IL within margins shifts inner down (row3)" \
+	"$FILL"'\033[2;3H\033[L' 2 'ccbbbbbbcccc'
+
+# IL at row2 col1 (col1 is OUTSIDE the margins) must be a complete no-op.
+capture_row "IL outside margins is a no-op (row2)" \
+	"$FILL"'\033[2;1H\033[L' 1 'bbbbbbbbbbbb'
+
+# ICH 3 at row1 col4 confined by the right margin: "ABCDEF" occupies cols
+# 3..8; inserting 3 blanks at col4 keeps 'A' at col3, pushes 'BC' to cols
+# 7..8, and drops "DEF" past the right margin.
+capture_row "ICH bounded by right margin" \
+	'\033[2J\033[H\033[?69h\033[3;8s\033[1;3HABCDEF\033[1;4H\033[3@' \
+	0 '  A   BC'
+
+# DCH 2 at row1 col4 confined by the right margin: deleting 'BC' pulls "DEF"
+# left, leaving "ADEF" at cols 3..6 and blanking cols 7..8.
+capture_row "DCH bounded by right margin" \
+	'\033[2J\033[H\033[?69h\033[3;8s\033[1;3HABCDEF\033[1;4H\033[2P' \
+	0 '  ADEF'
+
+# cursor_after <label> <printf-seq> <expected-cursor_x>
+# Runs a pane, then reports the pane cursor X (0-based) via display -p.
+cursor_after() {
+	_label=$1; _seq=$2; _expected=$3
+	$TMUX respawnw -k -t:0 -- sh -c "
+		exec 2>/dev/null
+		stty raw -echo
+		printf '$_seq'
+		sleep 10
+	" || exit 1
+	sleep 1.5
+	_actual=$($TMUX display -p -t:0 '#{cursor_x}')
+	if [ "$_actual" = "$_expected" ]; then
+		[ -n "$VERBOSE" ] && echo "[PASS] $_label -> cursor_x=$_actual"
+	else
+		echo "[FAIL] $_label: expected cursor_x=$_expected, got '$_actual'"
+		exit_status=1
+	fi
+}
+
+# ------------------------------------------------------------------
+# Test 9: HT (tab) stops at the right margin. Margins 3..6 (0-based right=5).
+# From the left margin the next default tab stop (0-based col 8) is past the
+# right margin, so the tab must clamp the cursor to the right margin (col 5).
+# ------------------------------------------------------------------
+cursor_after "HT clamps to right margin" \
+	'\033[2J\033[H\033[?69h\033[3;6s\033[1;3H\t' \
+	5
+
+# ------------------------------------------------------------------
+# Test 10: CBT (back-tab) does not cross the left margin. Margins 3..8
+# (0-based left=2). From col 8 with no tab stops inside the region, back-tab
+# must clamp the cursor to the left margin (0-based col 2).
+# ------------------------------------------------------------------
+cursor_after "CBT clamps to left margin" \
+	'\033[2J\033[H\033[?69h\033[3;8s\033[1;8H\033[Z' \
+	2
+
+# ------------------------------------------------------------------
+# Test 11: RIS (ESC c) clears the mode. Set ?69, then RIS, then DECRQM -> ;2.
+# ------------------------------------------------------------------
+query_decrpm "$TMP" "?69" '\033[?69h\033c' 9
+check "DECRQM 69 (reset by RIS)" '^[[?69;2$y'
+
+# ------------------------------------------------------------------
+# Test 12: DECALN (ESC # 8) resets margins. Set ?69 and margins, DECALN fills
+# the 80-column screen with E and resets margins to full width; writing 'ZZZ'
+# from home lands at column 1 (not the old left margin), proving the reset.
+# ------------------------------------------------------------------
+DECALN_EXPECTED=ZZZ$(awk 'BEGIN{for(i=0;i<77;i++)printf "E"}')
+capture_row "DECALN resets margins (write from col1)" \
+	'\033[?69h\033[3;8s\033#8\033[HZZZ' \
+	0 "$DECALN_EXPECTED"
+
+# ------------------------------------------------------------------
+# Test 13: resizing the window while margins are active must not leave the
+# right margin pointing past the (smaller) grid. Set margins near the right
+# edge, shrink the width below them, and confirm the server survives and the
+# session still responds (no out-of-bounds crash).
+# ------------------------------------------------------------------
+$TMUX set -g window-size manual
+$TMUX respawnw -k -t:0 -- sh -c "
+	exec 2>/dev/null
+	stty raw -echo
+	printf '\033[?69h\033[60;78s'
+	sleep 10
+" || exit 1
+sleep 1
+$TMUX resizew -x 20 2>/dev/null
+$TMUX resizew -x 80 2>/dev/null
+sleep 0.5
+if $TMUX has-session 2>/dev/null; then
+	[ -n "$VERBOSE" ] && echo "[PASS] resize with margins survives (no OOB)"
+else
+	echo "[FAIL] resize with margins: server died (likely OOB)"
+	exit_status=1
+fi
+
+# ------------------------------------------------------------------
+# Test 14: a wide character shifted against the right margin must not leave a
+# dangling half, and the out-of-margin column must be preserved. Margins 1..6
+# (0-based right=5). Put Y at column 7 (outside), a wide char at columns 5-6
+# (the wide char occupies the right margin edge), then DCH at column 1. The
+# wide char stays whole inside the margins and Y at column 7 is untouched.
+# ------------------------------------------------------------------
+$TMUX respawnw -k -t:0 -- sh -c "
+	exec 2>/dev/null
+	stty raw -echo
+	printf '\033[2J\033[H\033[1;7HY\033[?69h\033[1;6s\033[1;5H\344\275\240\033[1;1H\033[P'
+	sleep 10
+" || exit 1
+sleep 1.5
+widerow=$($TMUX capturep -p -t:0 | sed -n 1p)
+# Expect: three leading spaces, the wide char, a space, then Y at column 7.
+if [ "$widerow" = "   $(printf '\344\275\240') Y" ]; then
+	[ -n "$VERBOSE" ] && echo "[PASS] wide char at right margin -> '$widerow'"
+else
+	echo "[FAIL] wide char at right margin: got '$widerow'"
+	exit_status=1
+fi
+
+# capture_row already keeps the pane alive; reuse it for the DCH wide-char cases.
+
+# ------------------------------------------------------------------
+# Test 15: DCH that splits a wide character at the deletion range end must not
+# destroy the innocent cell before it. Margins 1..10, row "ABCDEfg<W>z", cursor
+# at column 6, DCH 3: the wide char's remnant shifts left but 'E' at column 5
+# must survive. Expect "ABCDE z".
+# ------------------------------------------------------------------
+capture_row "DCH wide-split keeps prior cell" \
+	'\033[2J\033[H\033[?69h\033[1;10s\033[1;1HABCDEfg\344\275\240z\033[1;6H\033[3P' \
+	0 'ABCDE z'
+
+# ------------------------------------------------------------------
+# Test 16: DCH at the left margin that exposes a wide-character orphan must not
+# corrupt the column left of the left margin. Margins 3..10, "AB" at columns
+# 1..2 (outside), "C<W>xyz" from column 3, cursor at the left margin (col 3),
+# DCH 2: 'B' at column 2 (outside the margin) must be preserved. Expect
+# "AB xyz".
+# ------------------------------------------------------------------
+capture_row "DCH at left margin keeps out-of-margin cell" \
+	'\033[2J\033[H\033[?69h\033[3;10s\033[1;1HAB\033[1;3HC\344\275\240xyz\033[1;3H\033[2P' \
+	0 'AB xyz'
+
+# ------------------------------------------------------------------
+# Test 17: DCH deleting a run that both starts on one wide char's padding and
+# ends on another's lead must blank both orphans. Margins 1..20, row "A<W1><W2>xy"
+# (W1 cols 2-3, W2 cols 4-5), cursor on W1's trailing half (col 3), DCH 2 removes
+# W1's padding and W2's lead. Both wide chars are destroyed. Expect "A  xy".
+# ------------------------------------------------------------------
+capture_row "DCH clears both compound wide orphans" \
+	'\033[2J\033[H\033[?69h\033[1;20s\033[1;1HA\344\275\240\345\245\275xy\033[1;3H\033[2P' \
+	0 'A  xy'
+
+# ------------------------------------------------------------------
+# Test 18: DCH spanning the full margin width from the left margin must not
+# clear a wide character left of the left margin. "A<W>xyz" (W at cols 2-3)
+# printed before margins, then margins 3..10, cursor at the left margin (col 3,
+# W's trailing half), DCH 8 (full margin width). W at columns 2-3 is outside the
+# left margin and must be preserved. Expect "A<W>".
+# ------------------------------------------------------------------
+capture_row "DCH full-width from left margin keeps outside wide char" \
+	'\033[2J\033[H\033[1;1HA\344\275\240xyz\033[?69h\033[3;10s\033[1;3H\033[8P' \
+	0 "A$(printf '\344\275\240')"
+
+$TMUX kill-server 2>/dev/null
+
+exit $exit_status
diff --git a/screen-write.c b/screen-write.c
index a311296e..c9e5b961 100644
--- a/screen-write.c
+++ b/screen-write.c
@@ -59,6 +59,27 @@ struct screen_write_cline {
 TAILQ_HEAD(, screen_write_citem)  screen_write_citem_freelist =
     TAILQ_HEAD_INITIALIZER(screen_write_citem_freelist);
 
+/*
+ * Left and right margins. When left-right margin mode (DECLRMM, ?69) is not
+ * enabled these collapse to the full screen width, so the margin-aware paths
+ * behave exactly as before.
+ */
+static u_int
+screen_write_left(struct screen *s)
+{
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN)
+		return (s->rleft);
+	return (0);
+}
+
+static u_int
+screen_write_right(struct screen *s)
+{
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN)
+		return (s->rright);
+	return (screen_size_x(s) - 1);
+}
+
 static struct screen_write_citem *
 screen_write_get_citem(void)
 {
@@ -275,6 +296,8 @@ screen_write_initctx(struct screen_write_ctx *ctx, struct tty_ctx *ttyctx,
 	ttyctx->ocy = s->cy;
 	ttyctx->orlower = s->rlower;
 	ttyctx->orupper = s->rupper;
+	ttyctx->orleft = s->rleft;
+	ttyctx->orright = s->rright;
 
 	if (check_obscured && screen_write_pane_is_obscured(ctx))
 		ttyctx->flags |= TTY_CTX_PANE_OBSCURED;
@@ -424,6 +447,7 @@ screen_write_reset(struct screen_write_ctx *ctx)
 
 	screen_reset_tabs(s);
 	screen_write_scrollregion(ctx, 0, screen_size_y(s) - 1);
+	screen_write_setmargins(ctx, 0, screen_size_x(s) - 1);
 
 	s->mode = MODE_CURSOR|MODE_WRAP;
 
@@ -1120,13 +1144,21 @@ void
 screen_write_cursorright(struct screen_write_ctx *ctx, u_int nx)
 {
 	struct screen	*s = ctx->s;
-	u_int		 cx = s->cx, cy = s->cy;
+	u_int		 cx = s->cx, cy = s->cy, limit;
 
 	if (nx == 0)
 		nx = 1;
 
-	if (nx > screen_size_x(s) - 1 - cx)
-		nx = screen_size_x(s) - 1 - cx;
+	/*
+	 * Stop at the right margin if the cursor starts at or before it,
+	 * otherwise (already past the margin) at the right edge of the screen.
+	 */
+	limit = screen_write_right(s);
+	if (cx > limit)
+		limit = screen_size_x(s) - 1;
+
+	if (nx > limit - cx)
+		nx = limit - cx;
 	if (nx == 0)
 		return;
 
@@ -1140,13 +1172,21 @@ void
 screen_write_cursorleft(struct screen_write_ctx *ctx, u_int nx)
 {
 	struct screen	*s = ctx->s;
-	u_int		 cx = s->cx, cy = s->cy;
+	u_int		 cx = s->cx, cy = s->cy, limit;
 
 	if (nx == 0)
 		nx = 1;
 
-	if (nx > cx)
-		nx = cx;
+	/*
+	 * Stop at the left margin if the cursor starts at or after it,
+	 * otherwise (already before the margin) at the left edge of the screen.
+	 */
+	limit = screen_write_left(s);
+	if (cx < limit)
+		limit = 0;
+
+	if (nx > cx - limit)
+		nx = cx - limit;
 	if (nx == 0)
 		return;
 
@@ -1169,8 +1209,10 @@ screen_write_backspace(struct screen_write_ctx *ctx)
 		gl = grid_get_line(s->grid, s->grid->hsize + cy - 1);
 		if (gl->flags & GRID_LINE_WRAPPED) {
 			cy--;
-			cx = screen_size_x(s) - 1;
+			cx = screen_write_right(s);
 		}
+	} else if (cx == screen_write_left(s)) {
+		/* Do not move past the left margin. */
 	} else
 		cx--;
 
@@ -1205,10 +1247,23 @@ screen_write_redraw_line(struct screen_write_ctx *ctx, struct tty_ctx *ttyctx,
 	struct screen		*s = ctx->s;
 	struct grid_cell	 gc, ngc;
 	u_int			 sx = screen_size_x(s), cx, i;
-	int			 xoff = wp->xoff, yoff = wp->yoff;
+	int			 xoff, yoff;
 	struct visible_ranges	*r;
 	struct visible_range	*ri;
 
+	/*
+	 * Without a pane (an overlay such as a popup) there is no window
+	 * geometry to redraw against; the grid is already updated, so request a
+	 * full redraw through the context callback instead.
+	 */
+	if (wp == NULL) {
+		if (ttyctx->redraw_cb != NULL)
+			ttyctx->redraw_cb(ttyctx);
+		return;
+	}
+	xoff = wp->xoff;
+	yoff = wp->yoff;
+
 	r = window_visible_ranges(wp, xoff, yoff + yy, sx, NULL);
 	for (i = 0; i < r->used; i++) {
 		ri = &r->ranges[i];
@@ -1292,6 +1347,16 @@ screen_write_redraw_pane(struct screen_write_ctx *ctx, struct tty_ctx *ttyctx)
 	struct screen	*s = ctx->s;
 	u_int		 yy;
 
+	/*
+	 * Without a pane (an overlay such as a popup) request a single full
+	 * redraw through the context callback rather than looping per line.
+	 */
+	if (ctx->wp == NULL) {
+		if (ttyctx->redraw_cb != NULL)
+			ttyctx->redraw_cb(ttyctx);
+		return;
+	}
+
 	for (yy = 0; yy < screen_size_y(s); yy++)
 		screen_write_redraw_line(ctx, ttyctx, yy);
 }
@@ -1323,6 +1388,9 @@ screen_write_alignmenttest(struct screen_write_ctx *ctx)
 	s->rupper = 0;
 	s->rlower = screen_size_y(s) - 1;
 
+	s->rleft = 0;
+	s->rright = screen_size_x(s) - 1;
+
 	screen_write_collect_clear(ctx, 0, screen_size_y(s) - 1);
 
 	screen_write_initctx(ctx, &ttyctx, 1, 1);
@@ -1363,6 +1431,26 @@ screen_write_insertcharacter(struct screen_write_ctx *ctx, u_int nx, u_int bg)
 	screen_write_initctx(ctx, &ttyctx, 0, 1);
 	ttyctx.bg = bg;
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		u_int	left = screen_write_left(s), right = screen_write_right(s);
+
+		if (s->cx < left || s->cx > right)
+			return;
+		if (nx > right - s->cx + 1)
+			nx = right - s->cx + 1;
+
+		grid_view_insert_cells_right(s->grid, s->cx, s->cy, nx, right, bg);
+
+		screen_write_collect_flush(ctx, 0, __func__);
+		ttyctx.n = nx;
+
+		if (!screen_write_should_draw_line(ctx, s->cy))
+			return;
+
+		screen_write_redraw_line(ctx, &ttyctx, s->cy);
+		return;
+	}
+
 	grid_view_insert_cells(s->grid, s->cx, s->cy, nx, bg);
 
 	screen_write_collect_flush(ctx, 0, __func__);
@@ -1404,6 +1492,27 @@ screen_write_deletecharacter(struct screen_write_ctx *ctx, u_int nx, u_int bg)
 	screen_write_initctx(ctx, &ttyctx, 0, 1);
 	ttyctx.bg = bg;
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		u_int	left = screen_write_left(s), right = screen_write_right(s);
+
+		if (s->cx < left || s->cx > right)
+			return;
+		if (nx > right - s->cx + 1)
+			nx = right - s->cx + 1;
+
+		grid_view_delete_cells_right(s->grid, s->cx, s->cy, nx, left,
+		    right, bg);
+
+		screen_write_collect_flush(ctx, 0, __func__);
+		ttyctx.n = nx;
+
+		if (!screen_write_should_draw_line(ctx, s->cy))
+			return;
+
+		screen_write_redraw_line(ctx, &ttyctx, s->cy);
+		return;
+	}
+
 	grid_view_delete_cells(s->grid, s->cx, s->cy, nx, bg);
 
 	screen_write_collect_flush(ctx, 0, __func__);
@@ -1478,6 +1587,15 @@ screen_write_insertline(struct screen_write_ctx *ctx, u_int ny, u_int bg)
 #endif
 
 	if (s->cy < s->rupper || s->cy > s->rlower) {
+		/*
+		 * With left-right margins active, IL only acts when the cursor
+		 * is inside the scroll region; outside it is a no-op (as in
+		 * xterm) rather than a full-width insert that would disturb
+		 * columns outside the margins.
+		 */
+		if (s->mode & MODE_LEFT_RIGHT_MARGIN)
+			return;
+
 		if (ny > sy - s->cy)
 			ny = sy - s->cy;
 		if (ny == 0)
@@ -1510,6 +1628,26 @@ screen_write_insertline(struct screen_write_ctx *ctx, u_int ny, u_int bg)
 	screen_write_initctx(ctx, &ttyctx, 1, 1);
 	ttyctx.bg = bg;
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		u_int	left = screen_write_left(s), right = screen_write_right(s);
+
+		if (s->cx < left || s->cx > right)
+			return;
+
+		grid_view_scroll_pad_region(gd, s->cy, s->rlower, left, right, 0,
+		    ny, bg);
+
+		screen_write_collect_flush(ctx, 0, __func__);
+		ttyctx.n = ny;
+
+		if (!screen_write_should_draw_lines(ctx, s->cy,
+		    s->rlower + 1 - s->cy))
+			return;
+
+		screen_write_redraw_pane(ctx, &ttyctx);
+		return;
+	}
+
 	if (s->cy < s->rupper || s->cy > s->rlower)
 		grid_view_insert_lines(gd, s->cy, ny, bg);
 	else
@@ -1546,6 +1684,15 @@ screen_write_deleteline(struct screen_write_ctx *ctx, u_int ny, u_int bg)
 #endif
 
 	if (s->cy < s->rupper || s->cy > s->rlower) {
+		/*
+		 * With left-right margins active, DL only acts when the cursor
+		 * is inside the scroll region; outside it is a no-op (as in
+		 * xterm) rather than a full-width delete that would disturb
+		 * columns outside the margins.
+		 */
+		if (s->mode & MODE_LEFT_RIGHT_MARGIN)
+			return;
+
 		if (ny > sy - s->cy)
 			ny = sy - s->cy;
 		if (ny == 0)
@@ -1580,6 +1727,25 @@ screen_write_deleteline(struct screen_write_ctx *ctx, u_int ny, u_int bg)
 	screen_write_initctx(ctx, &ttyctx, 1, 1);
 	ttyctx.bg = bg;
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		u_int	left = screen_write_left(s), right = screen_write_right(s);
+
+		if (s->cx < left || s->cx > right)
+			return;
+
+		grid_view_scroll_pad_region(gd, s->cy, s->rlower, left, right, 1,
+		    ny, bg);
+
+		screen_write_collect_flush(ctx, 0, __func__);
+		ttyctx.n = ny;
+
+		if (!screen_write_should_draw_lines(ctx, s->cy, ry))
+			return;
+
+		screen_write_redraw_pane(ctx, &ttyctx);
+		return;
+	}
+
 	if (s->cy < s->rupper || s->cy > s->rlower)
 		grid_view_delete_lines(gd, s->cy, ny, bg);
 	else
@@ -1707,6 +1873,19 @@ screen_write_cursormove(struct screen_write_ctx *ctx, int px, int py,
 			py += s->rupper;
 	}
 
+	/*
+	 * Under origin mode with left-right margins, the column is relative to
+	 * the left margin and clamped to the right margin (mirrors the row
+	 * handling above).
+	 */
+	if (origin && px != -1 && (s->mode & MODE_ORIGIN) &&
+	    (s->mode & MODE_LEFT_RIGHT_MARGIN)) {
+		if ((u_int)px > s->rright - s->rleft)
+			px = s->rright;
+		else
+			px += s->rleft;
+	}
+
 	if (px != -1 && (u_int)px > screen_size_x(s) - 1)
 		px = screen_size_x(s) - 1;
 	if (py != -1 && (u_int)py > screen_size_y(s) - 1)
@@ -1735,6 +1914,23 @@ screen_write_reverseindex(struct screen_write_ctx *ctx, u_int bg)
 		ctx->wp->flags |= PANE_REDRAW;
 #endif
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		screen_write_collect_flush(ctx, 0, __func__);
+
+		grid_view_scroll_pad_region(s->grid, s->rupper, s->rlower,
+		    screen_write_left(s), screen_write_right(s), 0, 1, bg);
+
+		screen_write_initctx(ctx, &ttyctx, 1, 1);
+		ttyctx.bg = bg;
+
+		ry = s->rlower + 1 - s->rupper;
+		if (!screen_write_should_draw_lines(ctx, s->rupper, ry))
+			return;
+
+		screen_write_redraw_pane(ctx, &ttyctx);
+		return;
+	}
+
 	grid_view_scroll_region_down(s->grid, s->rupper, s->rlower, bg);
 	screen_write_collect_flush(ctx, 0, __func__);
 
@@ -1775,6 +1971,37 @@ screen_write_scrollregion(struct screen_write_ctx *ctx, u_int rupper,
 	s->rlower = rlower;
 }
 
+/* Set left and right margins (DECSLRM). */
+void
+screen_write_setmargins(struct screen_write_ctx *ctx, u_int rleft, u_int rright)
+{
+	struct screen	*s = ctx->s;
+
+	if (rleft > screen_size_x(s) - 1)
+		rleft = screen_size_x(s) - 1;
+	if (rright > screen_size_x(s) - 1)
+		rright = screen_size_x(s) - 1;
+	if (rleft >= rright)	/* cannot be one column */
+		return;
+
+	screen_write_collect_flush(ctx, 0, __func__);
+
+	s->rleft = rleft;
+	s->rright = rright;
+
+	log_debug("%s: margins now %u-%u", __func__, rleft, rright);
+
+	/*
+	 * The cursor moves to the home position, which is the top-left of the
+	 * scroll region under origin mode and the top-left of the screen
+	 * otherwise (mirrors DECSTBM).
+	 */
+	if (s->mode & MODE_ORIGIN)
+		screen_write_set_cursor(ctx, rleft, s->rupper);
+	else
+		screen_write_set_cursor(ctx, 0, 0);
+}
+
 /* Line feed. */
 void
 screen_write_linefeed(struct screen_write_ctx *ctx, int wrapped, u_int bg)
@@ -1782,6 +2009,7 @@ screen_write_linefeed(struct screen_write_ctx *ctx, int wrapped, u_int bg)
 	struct screen		*s = ctx->s;
 	struct grid		*gd = s->grid;
 	struct grid_line	*gl;
+	struct tty_ctx		 ttyctx;
 #ifdef ENABLE_SIXEL
 	int			 redraw = 0;
 #endif
@@ -1814,6 +2042,25 @@ screen_write_linefeed(struct screen_write_ctx *ctx, int wrapped, u_int bg)
 		ctx->wp->flags |= PANE_REDRAW;
 #endif
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		u_int	ry;
+
+		screen_write_collect_flush(ctx, 0, __func__);
+
+		grid_view_scroll_pad_region(gd, s->rupper, s->rlower,
+		    screen_write_left(s), screen_write_right(s), 1, 1, bg);
+
+		screen_write_initctx(ctx, &ttyctx, 1, 1);
+		ttyctx.bg = bg;
+
+		ry = s->rlower + 1 - s->rupper;
+		if (!screen_write_should_draw_lines(ctx, s->rupper, ry))
+			return;
+
+		screen_write_redraw_pane(ctx, &ttyctx);
+		return;
+	}
+
 	grid_view_scroll_region_up(gd, s->rupper, s->rlower, bg);
 	screen_write_collect_scroll(ctx, bg);
 	ctx->scrolled++;
@@ -1825,6 +2072,7 @@ screen_write_scrollup(struct screen_write_ctx *ctx, u_int lines, u_int bg)
 {
 	struct screen	*s = ctx->s;
 	struct grid	*gd = s->grid;
+	struct tty_ctx	 ttyctx;
 	u_int		 i;
 
 	if (lines == 0)
@@ -1842,6 +2090,25 @@ screen_write_scrollup(struct screen_write_ctx *ctx, u_int lines, u_int bg)
 		ctx->wp->flags |= PANE_REDRAW;
 #endif
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		u_int	ry;
+
+		screen_write_collect_flush(ctx, 0, __func__);
+
+		grid_view_scroll_pad_region(gd, s->rupper, s->rlower,
+		    screen_write_left(s), screen_write_right(s), 1, lines, bg);
+
+		screen_write_initctx(ctx, &ttyctx, 1, 1);
+		ttyctx.bg = bg;
+
+		ry = s->rlower + 1 - s->rupper;
+		if (!screen_write_should_draw_lines(ctx, s->rupper, ry))
+			return;
+
+		screen_write_redraw_pane(ctx, &ttyctx);
+		return;
+	}
+
 	for (i = 0; i < lines; i++) {
 		grid_view_scroll_region_up(gd, s->rupper, s->rlower, bg);
 		screen_write_collect_scroll(ctx, bg);
@@ -1871,6 +2138,21 @@ screen_write_scrolldown(struct screen_write_ctx *ctx, u_int lines, u_int bg)
 		ctx->wp->flags |= PANE_REDRAW;
 #endif
 
+	if (s->mode & MODE_LEFT_RIGHT_MARGIN) {
+		grid_view_scroll_pad_region(gd, s->rupper, s->rlower,
+		    screen_write_left(s), screen_write_right(s), 0, lines, bg);
+
+		screen_write_collect_flush(ctx, 0, __func__);
+		ttyctx.n = lines;
+
+		ry = s->rlower + 1 - s->rupper;
+		if (!screen_write_should_draw_lines(ctx, s->rupper, ry))
+			return;
+
+		screen_write_redraw_pane(ctx, &ttyctx);
+		return;
+	}
+
 	for (i = 0; i < lines; i++)
 		grid_view_scroll_region_down(gd, s->rupper, s->rlower, bg);
 
@@ -1892,7 +2174,17 @@ screen_write_scrolldown(struct screen_write_ctx *ctx, u_int lines, u_int bg)
 void
 screen_write_carriagereturn(struct screen_write_ctx *ctx)
 {
-	screen_write_set_cursor(ctx, 0, -1);
+	struct screen	*s = ctx->s;
+	u_int		 cx = 0;
+
+	/*
+	 * Return to the left margin, unless the cursor is already to the left
+	 * of it, in which case return to the left edge of the screen.
+	 */
+	if (s->cx >= screen_write_left(s))
+		cx = screen_write_left(s);
+
+	screen_write_set_cursor(ctx, cx, -1);
 }
 
 /* Clear to end of screen from cursor. */
@@ -2586,6 +2878,8 @@ screen_write_collect_add(struct screen_write_ctx *ctx,
 		collect = 0;
 	else if (s->mode & MODE_INSERT)
 		collect = 0;
+	else if (s->mode & MODE_LEFT_RIGHT_MARGIN)
+		collect = 0;
 	else if (s->sel != NULL)
 		collect = 0;
 	if (!collect) {
@@ -2627,6 +2921,7 @@ screen_write_cell(struct screen_write_ctx *ctx, const struct grid_cell *gc)
 	struct tty_ctx		 ttyctx;
 	u_int			 sx = screen_size_x(s), sy = screen_size_y(s);
 	u_int			 width = ud->width, xx, not_wrap, i, n, vis;
+	u_int			 mlx, rx;
 	int			 selected, skip = 1, redraw = 0;
 	int			 yoff = 0, xoff = 0;
 	struct visible_ranges	*r;
@@ -2636,6 +2931,15 @@ screen_write_cell(struct screen_write_ctx *ctx, const struct grid_cell *gc)
 	if (gc->flags & GRID_FLAG_PADDING)
 		return;
 
+	/*
+	 * Effective horizontal bounds. Without left-right margin mode these are
+	 * the left edge and the screen width, so the wrap and advance logic is
+	 * unchanged; with margins active rx is one past the right margin and mlx
+	 * is the left margin.
+	 */
+	mlx = screen_write_left(s);
+	rx = screen_write_right(s) + 1;
+
 	/* Get the previous cell to check for combining. */
 	if (screen_write_combine(ctx, gc) != 0)
 		return;
@@ -2655,11 +2959,18 @@ screen_write_cell(struct screen_write_ctx *ctx, const struct grid_cell *gc)
 		skip = 0;
 	}
 
-	/* Check this will fit on the current line and wrap if not. */
-	if ((s->mode & MODE_WRAP) && s->cx > sx - width) {
+	/*
+	 * Check this will fit on the current line and wrap if not. With
+	 * left-right margins the wrap happens at the right margin and returns
+	 * to the left margin; rx == sx and mlx == 0 without margins so this is
+	 * the original behaviour. Only wrap when the cursor is within the
+	 * margins, matching the region the right margin governs.
+	 */
+	if ((s->mode & MODE_WRAP) && s->cx >= mlx && rx >= width &&
+	    s->cx > rx - width) {
 		log_debug("%s: wrapped at %u,%u", __func__, s->cx, s->cy);
 		screen_write_linefeed(ctx, 1, 8);
-		screen_write_set_cursor(ctx, 0, -1);
+		screen_write_set_cursor(ctx, mlx, -1);
 		screen_write_collect_flush(ctx, 0, __func__);
 	}
 
@@ -2740,10 +3051,12 @@ screen_write_cell(struct screen_write_ctx *ctx, const struct grid_cell *gc)
 	 * replace it.
 	 */
 	not_wrap = !(s->mode & MODE_WRAP);
-	if (s->cx <= sx - not_wrap - width)
+	if (s->cx >= mlx && s->cx <= rx - not_wrap - width)
+		screen_write_set_cursor(ctx, s->cx + width, -1);
+	else if (s->cx < mlx)
 		screen_write_set_cursor(ctx, s->cx + width, -1);
 	else
-		screen_write_set_cursor(ctx, sx - not_wrap, -1);
+		screen_write_set_cursor(ctx, rx - not_wrap, -1);
 
 	/* Create space for character in insert mode. */
 	if (s->mode & MODE_INSERT) {
@@ -2825,7 +3138,8 @@ screen_write_combine(struct screen_write_ctx *ctx, const struct grid_cell *gc)
 		zero_width = 1;
 	else if (utf8_is_vs(ud)) {
 		zero_width = 1;
-		if (options_get_number(oo, "variation-selector-always-wide"))
+		if ((s->mode & MODE_GRAPHEME_CLUSTERS) ||
+		    options_get_number(oo, "variation-selector-always-wide"))
 			force_wide = 1;
 	} else if (ud->width == 0)
 		zero_width = 1;
@@ -2864,15 +3178,20 @@ screen_write_combine(struct screen_write_ctx *ctx, const struct grid_cell *gc)
 				force_wide = 1;
 			else if (utf8_should_combine(ud, &last.data))
 				force_wide = 1;
-			else if (!utf8_has_zwj(&last.data))
+			else if (!utf8_has_zwj(&last.data) &&
+			    ((~s->mode & MODE_GRAPHEME_CLUSTERS) ||
+			    !utf8_grapheme_joins(&last.data, ud)))
 				return (0);
 			break;
 		}
 	}
 
 	/* Check if this combined character would be too long. */
-	if (last.data.size + ud->size > sizeof last.data.data)
+	if (last.data.size + ud->size > sizeof last.data.data) {
+		log_debug("%s: %.*s would be too long, not combining", __func__,
+		    (int)ud->size, ud->data);
 		return (0);
+	}
 
 	/* Combining; flush any pending output. */
 	screen_write_collect_flush(ctx, 0, __func__);
diff --git a/screen.c b/screen.c
index 6b539b38..705c24af 100644
--- a/screen.c
+++ b/screen.c
@@ -112,6 +112,9 @@ screen_reinit(struct screen *s, int check)
 	s->rupper = 0;
 	s->rlower = screen_size_y(s) - 1;
 
+	s->rleft = 0;
+	s->rright = screen_size_x(s) - 1;
+
 	s->mode = MODE_CURSOR|MODE_WRAP|(s->mode & MODE_CRLF);
 
 	if (options_get_number(global_options, "extended-keys") == 2)
@@ -375,6 +378,10 @@ screen_resize_cursor(struct screen *s, u_int sx, u_int sy, int reflow,
 	if (sy != screen_size_y(s))
 		screen_resize_y(s, sy, eat_empty, &cy);
 
+	/* Reset the left and right margins (covers a width-only resize). */
+	s->rleft = 0;
+	s->rright = screen_size_x(s) - 1;
+
 #ifdef ENABLE_SIXEL
 	image_free_all(s);
 #endif
@@ -841,6 +848,12 @@ screen_mode_to_string(int mode)
 		strlcat(tmp, "THEME_UPDATES,", sizeof tmp);
 	if (mode & MODE_SYNC)
 		strlcat(tmp, "SYNC,", sizeof tmp);
+	if (mode & MODE_RESIZE_REPORT)
+		strlcat(tmp, "RESIZE_REPORT,", sizeof tmp);
+	if (mode & MODE_GRAPHEME_CLUSTERS)
+		strlcat(tmp, "GRAPHEME_CLUSTERS,", sizeof tmp);
+	if (mode & MODE_LEFT_RIGHT_MARGIN)
+		strlcat(tmp, "LEFT_RIGHT_MARGIN,", sizeof tmp);
 	if (*tmp != '\0')
 		tmp[strlen(tmp) - 1] = '\0';
 	return (tmp);
diff --git a/tmux.h b/tmux.h
index 877aee7c..f876579e 100644
--- a/tmux.h
+++ b/tmux.h
@@ -690,6 +690,9 @@ enum tty_code_code {
 #define MODE_KEYS_EXTENDED_2 0x40000
 #define MODE_THEME_UPDATES 0x80000
 #define MODE_SYNC 0x100000
+#define MODE_RESIZE_REPORT 0x200000
+#define MODE_GRAPHEME_CLUSTERS 0x400000
+#define MODE_LEFT_RIGHT_MARGIN 0x800000
 
 #define ALL_MODES 0xffffff
 #define ALL_MOUSE_MODES (MODE_MOUSE_STANDARD|MODE_MOUSE_BUTTON|MODE_MOUSE_ALL)
@@ -1061,6 +1064,9 @@ struct screen {
 	u_int				 rupper;  /* scroll region top */
 	u_int				 rlower;  /* scroll region bottom */
 
+	u_int				 rleft;   /* left margin (DECSLRM) */
+	u_int				 rright;  /* right margin (DECSLRM) */
+
 	int				 mode;
 	int				 default_mode;
 
@@ -1852,6 +1858,8 @@ struct tty_ctx {
 
 	u_int			 orupper;
 	u_int			 orlower;
+	u_int			 orleft;
+	u_int			 orright;
 
 	/* Target region (usually pane) offset and size. */
 	int			 xoff;
@@ -3522,6 +3530,8 @@ void	 grid_view_clear_history(struct grid *, u_int);
 void	 grid_view_clear(struct grid *, u_int, u_int, u_int, u_int, u_int);
 void	 grid_view_scroll_region_up(struct grid *, u_int, u_int, u_int);
 void	 grid_view_scroll_region_down(struct grid *, u_int, u_int, u_int);
+void	 grid_view_scroll_pad_region(struct grid *, u_int, u_int, u_int, u_int,
+	     int, u_int, u_int);
 void	 grid_view_insert_lines(struct grid *, u_int, u_int, u_int);
 void	 grid_view_insert_lines_region(struct grid *, u_int, u_int, u_int,
 	     u_int);
@@ -3529,7 +3539,11 @@ void	 grid_view_delete_lines(struct grid *, u_int, u_int, u_int);
 void	 grid_view_delete_lines_region(struct grid *, u_int, u_int, u_int,
 	     u_int);
 void	 grid_view_insert_cells(struct grid *, u_int, u_int, u_int, u_int);
+void	 grid_view_insert_cells_right(struct grid *, u_int, u_int, u_int, u_int,
+	     u_int);
 void	 grid_view_delete_cells(struct grid *, u_int, u_int, u_int, u_int);
+void	 grid_view_delete_cells_right(struct grid *, u_int, u_int, u_int, u_int,
+	     u_int, u_int);
 char	*grid_view_string_cells(struct grid *, u_int, u_int, u_int);
 
 /* screen-write.c */
@@ -3588,6 +3602,7 @@ void	 screen_write_clearstartofline(struct screen_write_ctx *, u_int);
 void	 screen_write_cursormove(struct screen_write_ctx *, int, int, int);
 void	 screen_write_reverseindex(struct screen_write_ctx *, u_int);
 void	 screen_write_scrollregion(struct screen_write_ctx *, u_int, u_int);
+void	 screen_write_setmargins(struct screen_write_ctx *, u_int, u_int);
 void	 screen_write_linefeed(struct screen_write_ctx *, int, u_int);
 void	 screen_write_scrollup(struct screen_write_ctx *, u_int, u_int);
 void	 screen_write_scrolldown(struct screen_write_ctx *, u_int, u_int);
@@ -3784,6 +3799,8 @@ int		 window_pane_get_bg_control_client(struct window_pane *);
 int		 window_get_bg_client(struct window_pane *);
 enum client_theme window_pane_get_theme(struct window_pane *);
 void		 window_pane_send_theme_update(struct window_pane *);
+void		 window_pane_send_resize_report(struct window_pane *, u_int,
+		     u_int);
 enum pane_lines	 window_pane_get_pane_lines(struct window_pane *);
 enum pane_lines	 window_get_pane_lines(struct window *);
 int		 window_get_pane_status(struct window *);
@@ -4092,6 +4109,8 @@ int		 utf8_is_vs(const struct utf8_data *);
 int		 utf8_is_hangul_filler(const struct utf8_data *);
 int		 utf8_should_combine(const struct utf8_data *,
 		    const struct utf8_data *);
+int		 utf8_grapheme_joins(const struct utf8_data *,
+		    const struct utf8_data *);
 enum hanguljamo_state hanguljamo_check_state(const struct utf8_data *,
 		    const struct utf8_data *);
 
diff --git a/tty.c b/tty.c
index a0d21273..1da59f10 100644
--- a/tty.c
+++ b/tty.c
@@ -1720,6 +1720,7 @@ tty_cmd_insertline(struct tty *tty, const struct tty_ctx *ctx)
 	struct client	*c = tty->client;
 
 	if ((ctx->flags & TTY_CTX_WINDOW_BIGGER) ||
+	    ctx->orleft != 0 || ctx->orright != ctx->sx - 1 ||
 	    !tty_full_width(tty, ctx) ||
 	    tty_fake_bce(tty, &ctx->defaults, ctx->bg) ||
 	    !tty_term_has(tty->term, TTYC_CSR) ||
@@ -1747,6 +1748,7 @@ tty_cmd_deleteline(struct tty *tty, const struct tty_ctx *ctx)
 	struct client	*c = tty->client;
 
 	if ((ctx->flags & TTY_CTX_WINDOW_BIGGER) ||
+	    ctx->orleft != 0 || ctx->orright != ctx->sx - 1 ||
 	    !tty_full_width(tty, ctx) ||
 	    tty_fake_bce(tty, &ctx->defaults, ctx->bg) ||
 	    !tty_term_has(tty->term, TTYC_CSR) ||
@@ -1836,6 +1838,7 @@ tty_cmd_linefeed(struct tty *tty, const struct tty_ctx *ctx)
 		return;
 
 	if ((ctx->flags & TTY_CTX_WINDOW_BIGGER) ||
+	    ctx->orleft != 0 || ctx->orright != ctx->sx - 1 ||
 	    (!tty_full_width(tty, ctx) && !tty_use_margin(tty)) ||
 	    tty_fake_bce(tty, &ctx->defaults, 8) ||
 	    !tty_term_has(tty->term, TTYC_CSR) ||
@@ -1876,6 +1879,7 @@ tty_cmd_scrollup(struct tty *tty, const struct tty_ctx *ctx)
 	u_int			 i;
 
 	if ((ctx->flags & TTY_CTX_WINDOW_BIGGER) ||
+	    ctx->orleft != 0 || ctx->orright != ctx->sx - 1 ||
 	    (!tty_full_width(tty, ctx) && !tty_use_margin(tty)) ||
 	    tty_fake_bce(tty, &ctx->defaults, 8) ||
 	    !tty_term_has(tty->term, TTYC_CSR) ||
diff --git a/utf8-combined.c b/utf8-combined.c
index 02abc351..502ac889 100644
--- a/utf8-combined.c
+++ b/utf8-combined.c
@@ -310,3 +310,32 @@ hanguljamo_check_state(const struct utf8_data *p_ud, const struct utf8_data *ud)
 	}
 	return (HANGULJAMO_STATE_NOT_HANGULJAMO);
 }
+
+#ifdef HAVE_UTF8PROC
+/*
+ * Would UAX #29 keep the new character in the same extended grapheme cluster
+ * as the existing combined character (DECSET 2027)? Regional indicators are
+ * excluded: pair state lives in utf8_should_combine.
+ */
+int
+utf8_grapheme_joins(const struct utf8_data *prev, const struct utf8_data *add)
+{
+	wchar_t	a;
+
+	if (prev->size == 0)
+		return (0);
+	if (utf8_towc(add, &a) != UTF8_DONE)
+		return (0);
+	if (a >= 0x1F1E6 && a <= 0x1F1FF)
+		return (0);
+	return (!utf8proc_grapheme_breakable((const char *)prev->data,
+	    prev->size, a));
+}
+#else
+int
+utf8_grapheme_joins(__unused const struct utf8_data *prev,
+    __unused const struct utf8_data *add)
+{
+	return (0);
+}
+#endif
diff --git a/window.c b/window.c
index abeb87a1..7e0d104f 100644
--- a/window.c
+++ b/window.c
@@ -607,6 +607,32 @@ window_pane_send_resize(struct window_pane *wp, u_int sx, u_int sy)
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
