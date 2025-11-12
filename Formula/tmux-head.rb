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
  depends_on "jemalloc-head"

  uses_from_macos "bison" => :build # for yacc

  def install
    system "sh", "autogen.sh" if build.head?

    args = %W[
      --with-TERM=tmux-256color
      --enable-sixel
      --sysconfdir=#{etc}
      --enable-utf8proc=#{Formula["utf8proc-head"].opt_prefix}
      --enable-jemalloc
    ]

    ENV["JEMALLOC_CFLAGS"] = "-I#{Formula["jemalloc-head"].opt_include}"
    ENV["JEMALLOC_LIBS"] = "#{Formula["jemalloc-head"].opt_lib}/libjemalloc.a"
    ENV["LIBEVENT_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_CORE_CFLAGS"] = "-I#{Formula["libevent-head"].opt_include}"
    ENV["LIBEVENT_CORE_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent_core.a"
    ENV["LIBEVENT_LIBS"] = "#{Formula["libevent-head"].opt_lib}/libevent.a"
    ENV["LIBNCURSESW_CFLAGS"] = "-I#{Formula["ncurses-head"].opt_include} -I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV["LIBNCURSESW_LIBS"] = "#{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    ENV["LIBUTF8PROC_CFLAGS"] = "-I#{Formula["utf8proc-head"].opt_include}"
    ENV["LIBUTF8PROC_LIBS"] = "#{Formula["utf8proc-head"].opt_lib}/libutf8proc.a"

    target_cpu_flags = Hardware::CPU.intel? ? "-march=x86-64-v4 -mtune=skylake-avx512" : "-march=native"
    cflags = "#{target_cpu_flags} -O3 -ffast-math -flto -std=c2x"
    ldflags = "#{target_cpu_flags} -O3 -ffast-math -lresolv"
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags

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
