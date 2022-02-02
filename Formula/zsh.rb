class Zsh < Formula
  desc "UNIX shell (command interpreter)"
  homepage "https://www.zsh.org/"

  head do
    url "https://git.code.sf.net/p/zsh/code.git"
    mirror "https://github.com/zsh-users/zsh.git"

    depends_on "autoconf"
    depends_on "gdbm"
    depends_on "ncurses-head"
    depends_on "pcre"
    depends_on "yodl"
  end

  uses_from_macos "texinfo"

  def install
    # Work around configure issues with Xcode 12
    # https://www.zsh.org/mla/workers/2020/index.html
    # https://github.com/Homebrew/homebrew-core/issues/64921
    ENV.append "CFLAGS", "-Wno-implicit-function-declaration"
    ENV.append "CFLAGS", "-std=c11 -march=native -Ofast -flto"
    ENV.append "LDFLAGS", "-march=native -Ofast -flto"
    ENV.append "CPPFLAGS", "-D_DARWIN_C_SOURCE -I#{Formula["ncurses-head"].include}/ncursesw"
    ENV.append "LDFLAGS", "-L#{Formula["ncurses-head"].lib} -lncursesw"

    system "Util/preconfig" if build.head?

    system "./configure", "--prefix=#{prefix}",
           "--enable-fndir=#{pkgshare}/functions",
           "--enable-scriptdir=#{pkgshare}/scripts",
           "--enable-site-fndir=#{HOMEBREW_PREFIX}/share/zsh/site-functions",
           "--enable-site-scriptdir=#{HOMEBREW_PREFIX}/share/zsh/site-scripts",
           "--enable-runhelpdir=#{pkgshare}/help",
           "--enable-cap",
           "--enable-gdbm",
           "--enable-multibyte",
           "--enable-pcre",
           "--enable-zsh-secure-free",
           "--enable-unicode9",
           "--disable-etcdir",
           "--with-tcsetpgrp",
           "--disable-dynamic"

    inreplace "config.modules", "auto=yes", "auto=no"
    inreplace "config.modules" do |s|
      s.gsub! "name=zsh/main modfile=Src/zsh.mdd link=static auto=no load=yes", "name=zsh/main modfile=Src/zsh.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "name=zsh/sched modfile=Src/Builtins/sched.mdd link=static auto=no load=yes"  # enabled by default
      s.gsub! "name=zsh/attr modfile=Src/Modules/attr.mdd link=no auto=no load=no", "name=zsh/attr modfile=Src/Modules/attr.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/cap modfile=Src/Modules/cap.mdd link=no auto=no load=no", "name=zsh/cap modfile=Src/Modules/cap.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/clone modfile=Src/Modules/clone.mdd link=no auto=no load=no"  # disabled by default
      s.gsub! "name=zsh/curses modfile=Src/Modules/curses.mdd link=no auto=no load=no", "name=zsh/curses modfile=Src/Modules/curses.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/datetime modfile=Src/Modules/datetime.mdd link=static auto=no load=no functions=Functions/Calendar/*", "name=zsh/datetime modfile=Src/Modules/datetime.mdd link=static auto=no load=yes functions=Functions/Calendar/*"
      s.gsub! "name=zsh/db/gdbm modfile=Src/Modules/db_gdbm.mdd link=no auto=no load=no", "name=zsh/db/gdbm modfile=Src/Modules/db_gdbm.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/example modfile=Src/Modules/example.mdd link=no auto=no load=no"  # disabled by default
      s.gsub! "name=zsh/files modfile=Src/Modules/files.mdd link=no auto=no load=no", "name=zsh/files modfile=Src/Modules/files.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/langinfo modfile=Src/Modules/langinfo.mdd link=static auto=no load=no", "name=zsh/langinfo modfile=Src/Modules/langinfo.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/mapfile modfile=Src/Modules/mapfile.mdd link=no auto=no load=no", "name=zsh/mapfile modfile=Src/Modules/mapfile.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/mathfunc modfile=Src/Modules/mathfunc.mdd link=no auto=no load=no", "name=zsh/mathfunc modfile=Src/Modules/mathfunc.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/nearcolor modfile=Src/Modules/nearcolor.mdd link=no auto=no load=no"  # disabled by default
      # s.gsub! "name=zsh/newuser modfile=Src/Modules/newuser.mdd link=no auto=no load=no functions=Scripts/newuser Functions/Newuser/*"  # disabled by default
      s.gsub! "name=zsh/param/private modfile=Src/Modules/param_private.mdd link=no auto=no load=no", "name=zsh/param/private modfile=Src/Modules/param_private.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/pcre modfile=Src/Modules/pcre.mdd link=no auto=no load=no", "name=zsh/pcre modfile=Src/Modules/pcre.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/regex modfile=Src/Modules/regex.mdd link=no auto=no load=no", "name=zsh/regex modfile=Src/Modules/regex.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/net/socket modfile=Src/Modules/socket.mdd link=no auto=no load=no", "name=zsh/net/socket modfile=Src/Modules/socket.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/stat modfile=Src/Modules/stat.mdd link=no auto=no load=no", "name=zsh/stat modfile=Src/Modules/stat.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/system modfile=Src/Modules/system.mdd link=no auto=no load=no", "name=zsh/system modfile=Src/Modules/system.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/net/tcp modfile=Src/Modules/tcp.mdd link=no auto=no load=no", "name=zsh/net/tcp modfile=Src/Modules/tcp.mdd link=static auto=no load=yes"
      # s.gsub! "name=zsh/termcap modfile=Src/Modules/termcap.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "name=zsh/terminfo modfile=Src/Modules/terminfo.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "name=zsh/zftp modfile=Src/Modules/zftp.mdd link=no auto=no load=no functions=Functions/Zftp/*"  # disabled by default
      s.gsub! "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=no auto=no load=no", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=no auto=no load=no", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=no auto=no load=no", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes", "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes", "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes", "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes", "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"
      s.gsub! "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes", "name=zsh/rlimits modfile=Src/Builtins/rlimits.mdd link=static auto=no load=yes"
      # s.gsub! "config.modules", "name=zsh/zutil modfile=Src/Modules/zutil.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "config.modules", "name=zsh/compctl modfile=Src/Zle/compctl.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "config.modules", "name=zsh/complete modfile=Src/Zle/complete.mdd link=static auto=no load=yes functions=Completion/*comp* Completion/AIX/*/* Completion/BSD/*/* Completion/Base/*/* Completion/Cygwin/*/* Completion/Darwin/*/* Completion/Debian/*/* Completion/Linux/*/* Completion/Mandriva/*/* Completion/Redhat/*/* Completion/Solaris/*/* Completion/openSUSE/*/* Completion/Unix/*/* Completion/X/*/* Completion/Zsh/*/*"  # enable by default
      # s.gsub! "config.modules", "name=zsh/complist modfile=Src/Zle/complist.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "config.modules", "name=zsh/computil modfile=Src/Zle/computil.mdd link=static auto=no load=yes"  # enabled by default
      # s.gsub! "config.modules", "name=zsh/deltochar modfile=Src/Zle/deltochar.mdd link=no auto=no load=no"  # disabled by default
      # s.gsub! "config.modules", "name=zsh/zle modfile=Src/Zle/zle.mdd link=static auto=no load=yes functions=Functions/Zle/*"  # enabled by default
      # s.gsub! "config.modules", "name=zsh/zleparameter modfile=Src/Zle/zleparameter.mdd link=static auto=no load=yes"  # enabled by default
    end

    system "echo", "config.modules"
    system "cat", "config.modules"
    system "echo", "config.h"
    system "cat", "config.h"

    # Do not version installation directories.
    inreplace ["Makefile", "Src/Makefile"],
              "$(libdir)/$(tzsh)/$(VERSION)", "$(libdir)"

    system "make", "install"
    system "make", "install.bin", "install.modules", "install.fns"
  end

  test do
    assert_equal "homebrew", shell_output("#{bin}/zsh -c 'echo homebrew'").chomp
    system bin/"zsh", "-c", "printf -v hello -- '%s'"
  end
end
