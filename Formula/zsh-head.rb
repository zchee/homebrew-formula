class ZshHead < Formula
  desc "UNIX shell (command interpreter)"
  homepage "https://www.zsh.org/"
  license "MIT-Modern-Variant"

  livecheck do
    url "https://sourceforge.net/projects/zsh/rss?path=/zsh"
  end

  head do
    url "https://github.com/zsh-users/zsh.git"

    depends_on "autoconf"
    depends_on "gdbm"
    depends_on "ncurses-head"
    depends_on "pcre2"
    depends_on "yodl"
  end

  on_system :linux, macos: :ventura_or_newer do
    depends_on "texinfo" => :build
  end

  def install
    # Work around configure issues with Xcode 12
    # https://www.zsh.org/mla/workers/2020/index.html
    # https://github.com/Homebrew/homebrew-core/issues/64921
    cflags = "-Wno-implicit-function-declaration"
    ldflags = "-flto"
    if Hardware::CPU.intel?
      cflags += " -std=c11 -march=native -Ofast -flto"
      ldflags += " -march=native -Ofast"
    else
      cflags += " -march=native -Ofast"
      ldflags += " -march=native -Ofast"
    end
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags
    ENV.append "CPPFLAGS", "-D_DARWIN_C_SOURCE -I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV.append "LDFLAGS", "-L#{Formula["ncurses-head"].opt_lib} -lncursesw"

    puts "CFLAGS=#{ENV["CFLAGS"]}"
    puts "LDFLAGS=#{ENV["LDFLAGS"]}"
    puts "CPPFLAGS=#{ENV["CPPFLAGS"]}"

    system "Util/preconfig" if build.head?

    system "./configure", "--prefix=#{prefix}",
           "--enable-fndir=#{prefix}/share/zsh/functions",
           "--enable-scriptdir=#{prefix}/share/zsh/scripts",
           "--enable-site-fndir=#{HOMEBREW_PREFIX}/share/zsh/site-functions",
           "--enable-site-scriptdir=#{HOMEBREW_PREFIX}/share/zsh/site-scripts",
           "--enable-runhelpdir=#{prefix}/share/zsh/help",
           "--enable-cap",
           "--enable-gdbm",
           "--enable-multibyte",
           "--enable-pcre",
           "--enable-zsh-secure-free",
           "--enable-unicode9",
           "--disable-etcdir",
           "--with-tcsetpgrp",
           "--disable-dynamic"

    inreplace "config.modules", "name=zsh/attr modfile=Src/Modules/attr.mdd link=no auto=yes load=no", "name=zsh/attr modfile=Src/Modules/attr.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/curses modfile=Src/Modules/curses.mdd link=no auto=yes load=no", "name=zsh/curses modfile=Src/Modules/curses.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/datetime modfile=Src/Modules/datetime.mdd link=static auto=yes load=no functions=Functions/Calendar/*", "name=zsh/datetime modfile=Src/Modules/datetime.mdd link=static auto=no load=yes functions=Functions/Calendar/*"
    inreplace "config.modules", "name=zsh/db/gdbm modfile=Src/Modules/db_gdbm.mdd link=no auto=yes load=no", "name=zsh/db/gdbm modfile=Src/Modules/db_gdbm.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/files modfile=Src/Modules/files.mdd link=no auto=yes load=no", "name=zsh/files modfile=Src/Modules/files.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/langinfo modfile=Src/Modules/langinfo.mdd link=static auto=yes load=no", "name=zsh/langinfo modfile=Src/Modules/langinfo.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/mapfile modfile=Src/Modules/mapfile.mdd link=no auto=yes load=no", "name=zsh/mapfile modfile=Src/Modules/mapfile.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/mathfunc modfile=Src/Modules/mathfunc.mdd link=no auto=yes load=no", "name=zsh/mathfunc modfile=Src/Modules/mathfunc.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/param/private modfile=Src/Modules/param_private.mdd link=no auto=yes load=no", "name=zsh/param/private modfile=Src/Modules/param_private.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/pcre modfile=Src/Modules/pcre.mdd link=no auto=yes load=no", "name=zsh/pcre modfile=Src/Modules/pcre.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/regex modfile=Src/Modules/regex.mdd link=no auto=yes load=no", "name=zsh/regex modfile=Src/Modules/regex.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/net/socket modfile=Src/Modules/socket.mdd link=no auto=yes load=no", "name=zsh/net/socket modfile=Src/Modules/socket.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/stat modfile=Src/Modules/stat.mdd link=no auto=yes load=no", "name=zsh/stat modfile=Src/Modules/stat.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/system modfile=Src/Modules/system.mdd link=no auto=yes load=no", "name=zsh/system modfile=Src/Modules/system.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/termcap modfile=Src/Modules/termcap.mdd link=static auto=yes load=yes", "name=zsh/termcap modfile=Src/Modules/termcap.mdd link=no auto=no load=no"
    inreplace "config.modules", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=no auto=yes load=no", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=no auto=yes load=no", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=no auto=yes load=no", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=static auto=no load=yes"

    # Do not version installation directories.
    inreplace ["Makefile", "Src/Makefile"],
              "$(libdir)/$(tzsh)/$(VERSION)", "$(libdir)"

    system "make", "install.bin", "install.modules", "install.fns", "install.man"
  end

  test do
    assert_equal "homebrew", shell_output("#{bin}/zsh -c 'echo homebrew'").chomp
    system bin/"zsh", "-c", "printf -v hello -- '%s'"
  end
end
