class LessHead < Formula
  desc "Pager program similar to more"
  homepage "https://www.greenwoodsoftware.com/less/index.html"
  license "GPL-3.0-or-later"

  livecheck do
    url :homepage
    regex(/less[._-]v?(\d+(?:\.\d+)*).+?released.+?general use/i)
  end

  head do
    url "https://github.com/gwsw/less.git", branch: "master"
    depends_on "autoconf" => :build
    depends_on "groff" => :build
    uses_from_macos "perl" => :build
  end

  depends_on "ncurses-head" => :build
  depends_on "pcre2" => :build

  def install
    system "make", "-f", "Makefile.aut", "distfiles" if build.head?
    system "./configure", "--prefix=#{prefix}", "--with-regex=pcre2", "--enable-year2038"
    inreplace "Makefile", /(LIBS = \$\(LIBSAN\))  -lncursesw -lpcre2-8/, "\\1 #{Formula["pcre2"].opt_lib}/libpcre2-8.a #{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    system "make", "install"
  end

  test do
    system "#{bin}/lesskey", "-V"
  end
end
