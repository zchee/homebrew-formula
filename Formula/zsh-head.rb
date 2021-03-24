class ZshHead < Formula
  desc "UNIX shell (command interpreter)"
  homepage "https://www.zsh.org/"

  bottle :unneeded

  head do
    url "https://git.code.sf.net/p/zsh/code.git"
    depends_on "autoconf" => :build
  end

  depends_on "gdbm" => :build
  depends_on "ncurses-head" => :build
  depends_on "pcre" => :build
  depends_on "yodl" => :build

  def install
    # Work around configure issues with Xcode 12
    # https://www.zsh.org/mla/workers/2020/index.html
    # https://github.com/Homebrew/homebrew-core/issues/64921
    ENV.append "CFLAGS", "-Wno-implicit-function-declaration"
    ENV.prepend "CFLAGS", "-std=c17 -march=native -Ofast -flto"
    ENV.prepend "LDFLAGS", "-march=native -Ofast -flto"
    ENV.prepend "CPPFLAGS", "-D_DARWIN_C_SOURCE -I#{Formula["ncurses-head"].include}/ncursesw"
    ENV.prepend "LDFLAGS", "-L#{Formula["ncurses-head"].lib} -lncursesw"

    system "Util/preconfig" if build.head?

    system "./configure", "--prefix=#{prefix}",
           "--enable-fndir=#{pkgshare}/functions",
           "--enable-scriptdir=#{pkgshare}/scripts",
           "--enable-site-fndir=#{HOMEBREW_PREFIX}/share/zsh/site-functions",
           "--enable-site-scriptdir=#{HOMEBREW_PREFIX}/share/zsh/site-scripts",
           "--enable-runhelpdir=#{pkgshare}/help",
           "--enable-cap",
           "--enable-gdbm",
           "--enable-maildir-support",
           "--enable-multibyte",
           "--enable-pcre",
           "--enable-zsh-secure-free",
           "--enable-unicode9",
           "--enable-etcdir=/etc",
           "--with-tcsetpgrp",
           "--disable-dynamic"

    inreplace "config.modules", "auto=yes", "auto=no"
    inreplace "config.modules", "name=zsh/main modfile=Src/zsh.mdd link=static auto=no load=yes", "name=zsh/main modfile=Src/zsh.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/sched modfile=Src/Builtins/sched.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/attr modfile=Src/Modules/attr.mdd link=no auto=no load=no", "name=zsh/attr modfile=Src/Modules/attr.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/cap modfile=Src/Modules/cap.mdd link=no auto=no load=no", "name=zsh/cap modfile=Src/Modules/cap.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/clone modfile=Src/Modules/clone.mdd link=no auto=no load=no"
    inreplace "config.modules", "name=zsh/curses modfile=Src/Modules/curses.mdd link=no auto=no load=no", "name=zsh/curses modfile=Src/Modules/curses.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/datetime modfile=Src/Modules/datetime.mdd link=static auto=no load=no", "name=zsh/datetime modfile=Src/Modules/datetime.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/db/gdbm modfile=Src/Modules/db_gdbm.mdd link=no auto=no load=no", "name=zsh/db/gdbm modfile=Src/Modules/db_gdbm.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/example modfile=Src/Modules/example.mdd link=no auto=no load=no"
    inreplace "config.modules", "name=zsh/files modfile=Src/Modules/files.mdd link=no auto=no load=no", "name=zsh/files modfile=Src/Modules/files.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/langinfo modfile=Src/Modules/langinfo.mdd link=static auto=no load=no", "name=zsh/langinfo modfile=Src/Modules/langinfo.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/mapfile modfile=Src/Modules/mapfile.mdd link=no auto=no load=no", "name=zsh/mapfile modfile=Src/Modules/mapfile.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/mathfunc modfile=Src/Modules/mathfunc.mdd link=no auto=no load=no", "name=zsh/mathfunc modfile=Src/Modules/mathfunc.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/nearcolor modfile=Src/Modules/nearcolor.mdd link=no auto=no load=no"
    # inreplace "config.modules", "name=zsh/newuser modfile=Src/Modules/newuser.mdd link=no auto=no load=no functions=Scripts/newuser Functions/Newuser/*"
    inreplace "config.modules", "name=zsh/param/private modfile=Src/Modules/param_private.mdd link=no auto=no load=no", "name=zsh/param/private modfile=Src/Modules/param_private.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/parameter modfile=Src/Modules/parameter.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/pcre modfile=Src/Modules/pcre.mdd link=no auto=no load=no", "name=zsh/pcre modfile=Src/Modules/pcre.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/regex modfile=Src/Modules/regex.mdd link=no auto=no load=no", "name=zsh/regex modfile=Src/Modules/regex.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/net/socket modfile=Src/Modules/socket.mdd link=no auto=no load=no", "name=zsh/net/socket modfile=Src/Modules/socket.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/stat modfile=Src/Modules/stat.mdd link=no auto=no load=no", "name=zsh/stat modfile=Src/Modules/stat.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/system modfile=Src/Modules/system.mdd link=no auto=no load=no", "name=zsh/system modfile=Src/Modules/system.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/net/tcp modfile=Src/Modules/tcp.mdd link=no auto=no load=no", "name=zsh/net/tcp modfile=Src/Modules/tcp.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/termcap modfile=Src/Modules/termcap.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/terminfo modfile=Src/Modules/terminfo.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/zftp modfile=Src/Modules/zftp.mdd link=no auto=no load=no functions=Functions/Zftp/*"
    inreplace "config.modules", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=no auto=no load=no", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=no auto=no load=no", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=no auto=no load=no", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/zpython modfile=Src/Modules/zpython.mdd link=no auto=no load=no", "name=zsh/zpython modfile=Src/Modules/zpython.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/zutil modfile=Src/Modules/zutil.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/compctl modfile=Src/Zle/compctl.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/complete modfile=Src/Zle/complete.mdd link=static auto=no load=yes functions=Completion/*comp* Completion/AIX/*/* Completion/BSD/*/* Completion/Base/*/* Completion/Cygwin/*/* Completion/Darwin/*/* Completion/Debian/*/* Completion/Linux/*/* Completion/Mandriva/*/* Completion/Redhat/*/* Completion/Solaris/*/* Completion/openSUSE/*/* Completion/Unix/*/* Completion/X/*/* Completion/Zsh/*/*"
    # inreplace "config.modules", "name=zsh/complist modfile=Src/Zle/complist.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/computil modfile=Src/Zle/computil.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/deltochar modfile=Src/Zle/deltochar.mdd link=no auto=no load=no"
    # inreplace "config.modules", "name=zsh/zle modfile=Src/Zle/zle.mdd link=static auto=no load=yes functions=Functions/Zle/*"
    # inreplace "config.modules", "name=zsh/zleparameter modfile=Src/Zle/zleparameter.mdd link=static auto=no load=yes"

    system "echo", "config.modules"
    system "cat", "config.modules"
    system "echo", "config.h"
    system "cat", "config.h"

    # Do not version installation directories.
    inreplace ["Makefile", "Src/Makefile"],
              "$(libdir)/$(tzsh)/$(VERSION)", "$(libdir)"

    system "make", "install"
    system "make", "install.info"
  end

  test do
    assert_equal "homebrew", shell_output("#{bin}/zsh -c 'echo homebrew'").chomp
    system bin/"zsh", "-c", "printf -v hello -- '%s'"
  end
end