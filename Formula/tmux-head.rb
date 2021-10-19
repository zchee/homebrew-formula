class TmuxHead < Formula
  desc "Terminal multiplexer"
  homepage "https://tmux.github.io/"
  license "ISC"

  livecheck do
    url "https://github.com/tmux/tmux/releases/latest"
    regex(%r{href=.*?/tag/v?(\d+(?:\.\d+)+[a-z]?)["' >]}i)
  end

  head do
    url "https://github.com/tmux/tmux.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "bison" => :build
  end

  depends_on "pkg-config" => :build
  depends_on "libevent-head" => :build
  depends_on "ncurses-head" => :build
  depends_on "utf8proc-head" => :build

  resource "completion" do
    url "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux"
    sha256 "b5f7bbd78f9790026bbff16fc6e3fe4070d067f58f943e156bd1a8c3c99f6a6f"
  end

  def install
    ENV.append "CFLAGS", "-march=native -Ofast -flto"
    ENV.append "CPPFLAGS", "-I#{Formula["ncurses-head"].include}/ncursesw"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto -L#{Formula["ncurses-head"].lib} -lncursesw"
    ENV.append "LDFLAGS", "-lresolv"

    inreplace "configure.ac" do |s|
      s.gsub!(/AC_INIT\(\[tmux\],[^)]*\)/, "AC_INIT([tmux], master)")
    end

    inreplace "osdep-darwin.c" do |s|
      s.gsub!(/\tsetenv\("EVENT_NOPOLL", "1", 1\);\n/, "")
      s.gsub!(/\tunsetenv\("EVENT_NOPOLL"\);\n/, "")
    end

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
