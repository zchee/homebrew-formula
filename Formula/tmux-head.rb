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
    url "https://github.com/zchee/tmux-homebrew.git", branch: "homebrew"

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

    target_cpu_flags = Hardware::CPU.intel? ? "-march=x86-64-v4 -mtune=skylake-avx512" : "-march=apple-latest"
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
