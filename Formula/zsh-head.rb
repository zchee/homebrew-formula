class ZshHead < Formula
  desc "UNIX shell (command interpreter)"
  homepage "https://www.zsh.org/"
  license "MIT-Modern-Variant"

  livecheck do
    url "https://sourceforge.net/projects/zsh/rss?path=/zsh"
  end

  head do
    url "https://git.code.sf.net/p/zsh/code.git", branch: "master"
    depends_on "autoconf" => :build
    depends_on "gdbm" => :build
    depends_on "libiconv" => :build
    depends_on "ncurses" => :build
    depends_on "pcre2" => :build
    depends_on "yodl" => :build
  end

  on_system :linux, macos: :ventura_or_newer do
    depends_on "texinfo" => :build
  end

  def install
    # Work around configure issues with Xcode 12
    # https://www.zsh.org/mla/workers/2020/index.html
    # https://github.com/Homebrew/homebrew-core/issues/64921
    ENV.append_to_cflags "-Wno-implicit-function-declaration" if DevelopmentTools.clang_build_version >= 1200

    if Hardware::CPU.intel?
      cflags  = "-std=c11 -march=x86-64-v4 -Ofast -flto"
      ldflags = "-march=x86-64-v4 -Ofast -flto"
    else
      cflags  = "-march=apple-latest -Ofast -flto"
      ldflags = "-march=apple-latest -Ofast -flto"
    end
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags
    ENV.append "CPPFLAGS", "-D_DARWIN_C_SOURCE -I#{Formula["ncurses"].opt_include}/ncursesw"
    # TODO(zchee): static linking
    # ENV.append "LDFLAGS", "#{Formula["gdbm"].opt_lib}/libgdbm.a"
    # ENV.append "LDFLAGS", "#{Formula["ncurses"].opt_lib}/libncursesw.a"
    # ENV.append "LDFLAGS", "#{Formula["pcre2"].opt_lib}/libpcre2-8.a"
    # ENV.append "LDFLAGS", "#{Formula["libiconv"].opt_lib}/libiconv.a"

    system "Util/preconfig" if build.head?

    system "./configure", "--prefix=#{prefix}",
           "--enable-fndir=#{prefix}/share/zsh/functions",
           "--enable-scriptdir=#{prefix}/share/zsh/scripts",
           "--enable-site-fndir=#{HOMEBREW_PREFIX}/share/zsh/site-functions",
           "--enable-site-scriptdir=#{HOMEBREW_PREFIX}/share/zsh/site-scripts",
           "--enable-runhelpdir=#{prefix}/share/zsh/help",
           "--enable-cap",
           "--enable-multibyte",
           "--enable-pcre",
           "--enable-gdbm",
           "--enable-zsh-secure-free",
           "--enable-unicode9",
           "--enable-etcdir=/etc",
           "--with-tcsetpgrp",
           "--disable-dynamic",
           "DL_EXT=bundle"

    # Do not version installation directories.
    inreplace ["Makefile", "Src/Makefile"],
              "$(libdir)/$(tzsh)/$(VERSION)", "$(libdir)"

    # TODO(zchee): static linking
    # inreplace "Makefile" do |s|
    #   s.delete! "-L/usr/local/Cellar/pcre2/10.43/lib", ""
    #   s.delete! "-lpcre2-8", ""
    #   s.delete! "-lgdbm", ""
    #   s.delete! "-liconv", ""
    # end
    # inreplace "Src/Makefile" do |s|
    #   s.delete! "-L/usr/local/Cellar/pcre2/10.43/lib", ""
    #   s.delete! "-lpcre2-8", ""
    #   s.delete! "-lgdbm", ""
    #   s.delete! "-liconv", ""
    # end

    inreplace "config.modules", "link=no", "link=static"
    inreplace "config.modules", "auto=yes", "auto=no"
    inreplace "config.modules", "load=no", "load=yes"

    system "cat", "config.modules"

    system "make", "install.bin", "install.modules", "install.fns", "install.man"
  end

  test do
    assert_equal "homebrew", shell_output("#{bin}/zsh -c 'echo homebrew'").chomp
    system bin/"zsh", "-c", "printf -v hello -- '%s'"
  end
end
