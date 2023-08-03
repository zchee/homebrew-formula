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

  def install
    cflags = "-march=native -Ofast -flto -std=c2x -Wno-pointer-sign"
    ldflags = "-march=native -Ofast -flto"
    ldflags += " -L#{Formula["ncurses-head"].lib} -lresolv"

    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags
    ENV.append "CFLAGS", "-I#{Formula["pcre"].opt_include} -I#{Formula["utf8proc-head"].opt_include}"
    ENV.append "LDFLAGS", "#{Formula["utf8proc-head"].opt_lib}/libutf8proc.a"

    ENV.append "LIBEVENT_CFLAGS", "-I#{Formula["libevent-head"].opt_include}"
    ENV.append "LIBEVENT_LIBS", "#{Formula["libevent-head"].opt_lib}/libevent.a"
    ENV.append "LIBEVENT_CORE_LIBS", "#{Formula["libevent-head"].opt_lib}/libevent_core.a"
    ENV.append "LIBNCURSES_CFLAGS", "-I#{Formula["ncurses-head"].opt_include}/ncursesw -I#{Formula["ncurses-head"].opt_include} -D_DARWIN_C_SOURCE -DNCURSES_WIDECHAR"
    ENV.append "LIBNCURSES_LIBS", "#{Formula["ncurses-head"].opt_lib}/libncursesw.a"

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
