class TmuxHead < Formula
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

  depends_on "pkg-config" => :build
  depends_on "jemalloc-head"
  depends_on "libevent-head"
  depends_on "ncurses-head"

  depends_on "bison" => :build # for yacc
  # uses_from_macos "bison" => :build # for yacc

  # Old versions of macOS libc disagree with utf8proc character widths.
  # https://github.com/tmux/tmux/issues/2223
  on_system :linux, macos: :sierra_or_newer do
    depends_on "utf8proc-head"
  end

  resource "completion" do
    url "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/f5d53239f7658f8e8fbaf02535cc369009c436d6/completions/tmux"
    sha256 "b5f7bbd78f9790026bbff16fc6e3fe4070d067f58f943e156bd1a8c3c99f6a6f"
  end

  def install
    inreplace "configure.ac", /AC_INIT\(\[tmux\],[^)]*\)/, "AC_INIT([tmux], master)"

    system "sh", "autogen.sh" if build.head?

    args = %W[
      --enable-sixel
      --enable-jemalloc
      --sysconfdir=#{etc}
    ]

    if OS.mac?
      # tmux finds the `tmux-256color` terminfo provided by our ncurses
      # and uses that as the default `TERM`, but this causes issues for
      # tools that link with the very old ncurses provided by macOS.
      # https://github.com/Homebrew/homebrew-core/issues/102748
      args << "--with-TERM=screen-256color" if MacOS.version < :sonoma
      args << "--enable-utf8proc" if MacOS.version >= :high_sierra
      ENV["LIBUTF8PROC_CFLAGS"] = "-I#{Formula["utf8proc-head"].opt_include}" if MacOS.version >= :high_sierra
      ENV["LIBUTF8PROC_LIBS"] = "#{Formula["utf8proc-head"].opt_lib}/libutf8proc.a" if MacOS.version >= :high_sierra
    else
      args << "--enable-utf8proc"
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

    cflags = "-march=native -Ofast -flto -std=c2x"
    ldflags = "-march=native -Ofast -flto -L/usr/local/lib -lresolv"  # -lutil?
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags

    system "./configure", *std_configure_args, *args

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
    PTY.spawn bin/"tmux", "-S", socket, "-f", "/dev/null"
    sleep 10

    assert_predicate socket, :exist?
    assert_predicate socket, :socket?
    assert_equal "no server running on #{socket}", shell_output("#{bin}/tmux -S#{socket} list-sessions 2>&1", 1).chomp
  end
end
