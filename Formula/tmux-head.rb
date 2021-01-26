class TmuxHead < Formula
  desc "Terminal multiplexer"
  homepage "https://tmux.github.io/"
  license "ISC"

  livecheck do
    url "https://github.com/tmux/tmux/releases/latest"
    regex(%r{href=.*?/tag/v?(\d+(?:\.\d+)+[a-z]?)["' >]}i)
  end

  bottle :unneeded

  head do
    url "https://github.com/tmux/tmux.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "pkg-config" => :build
  depends_on "libevent-head" => :build
  depends_on "ncurses-head" => :build
  depends_on "utf8proc" => :build

  resource "completion" do
    url "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux"
  end

  def install
    system "sh", "autogen.sh"

    args = %W[
      --disable-dependency-tracking
      --enable-utf8proc
      --prefix=#{prefix}
      --sysconfdir=#{etc}
    ]

    ENV.append "CFLAGS", "-march=native -Ofast -flto"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto"
    ENV.append "LDFLAGS", "-lresolv"
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
