class ZshZpython < Formula
  desc "UNIX shell (command interpreter) with zpython"
  homepage "https://www.zsh.org/"
  head "https://github.com/zchee/zsh-zpython.git", :branch => "zpython"

  depends_on "autoconf" => :build
  depends_on "gdbm" => :build
  depends_on "ncurses-head" => :build
  depends_on "pcre" => :build
  depends_on "python" => :build
  depends_on "yodl" => :build

  # resource "htmldoc" do
  #   url "https://downloads.sourceforge.net/project/zsh/zsh-doc/5.8/zsh-5.8-doc.tar.xz"
  #   mirror "https://www.zsh.org/pub/zsh-5.8-doc.tar.xz"
  #   sha256 "9b4e939593cb5a76564d2be2e2bfbb6242509c0c56fd9ba52f5dba6cf06fdcc4"
  # end

      # "--enable-cflags='-std=c17 -march=native -Ofast -flto -isysroot/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk -isystem/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include -isystem/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk/usr/include -mmacosx-version-min=10.15 -Wno-implicit-function-declaration'"
      # "--enable-cppflags='-D_DARWIN_C_SOURCE -I/usr/local/opt/ncurses-head/include -I/usr/local/opt/ncurses-head/include/ncursesw -I/usr/local/opt/gdbm/include -I/usr/local/opt/libiconv/include -I/usr/local/opt/pcre/include -I/usr/local/opt/python@3.8/Frameworks/Python.framework/Versions/3.8/include/python3.8"
      # "--enable-ldflags='-march=native -Ofast -flto -undefined dynamic_lookup /usr/local/opt/ncurses-head/lib/libncursesw.a /usr/local/opt/libiconv/lib/libiconv.a /usr/local/opt/gdbm/lib/libgdbm.a /usr/local/opt/pcre/lib/libpcre.a /usr/local/opt/python@3.8/Frameworks/Python.framework/Versions/3.8/Python'"
      # "--enable-fndir='/usr/local/share/zsh/functions'"
      # "--enable-scriptdir='/usr/local/share/zsh/scripts'"
      # "--enable-site-fndir='/usr/local/share/zsh/site-functions'"
      # "--enable-site-scriptdir='/usr/local/share/zsh/site-scripts'"
      # "--enable-runhelpdir='/usr/local/share/zsh/help''"
      #
      # "--enable-cap"
      # "--enable-gdbm"
      # "--enable-multibyte"
      # "--enable-pcre"
      # "--enable-unicode9"
      # "--enable-zpython"
      # "--enable-zsh-secure-free"
      #
      # "--disable-dynamic"
      # "--disable-etcdir"
      #
      # "--with-python-config-dir='/usr/local/opt/python@3.8/Frameworks/Python.framework/Versions/3.8/lib/python3.8/config-3.8-darwin"
      # "--with-python-executable='/usr/local/opt/python@3.8/bin/python3.8"
      # "--with-python-version='3.8"
      # "--with-tcsetpgrp"
      # "--with-term-lib='ncursesw ncurses curses'"
      #
      # "CFLAGS='-isysroot/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk -isystem/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include -isystem/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk/usr/include -mmacosx-version-min=10.15'

  def install
    system "Util/preconfig"

    ENV.prepend "CFLAGS", "-std=c17 -march=native -Ofast -flto"
    ENV.prepend "LDFLAGS", "-march=native -Ofast -flto -undefined dynamic_lookup"
    ENV.prepend "CPPFLAGS", "-D_DARWIN_C_SOURCE -I#{Formula["ncurses-head"].include} -I#{Formula["ncurses-head"].include}/ncursesw -DNCURSES_WGETCH_EVENTS=1"
    ENV.prepend "LDFLAGS", "-L#{Formula["ncurses-head"].lib} -lncursesw"

    python = Formula["python"]
    python_version = python.version.to_s.slice(/(3\.\d)/)

    args = %W[
      --prefix=#{prefix}
      --enable-fndir=#{pkgshare}/functions
      --enable-scriptdir=#{pkgshare}/scripts
      --enable-site-fndir=#{HOMEBREW_PREFIX}/share/zsh/site-functions
      --enable-site-scriptdir=#{HOMEBREW_PREFIX}/share/zsh/site-scripts
      --enable-runhelpdir=#{pkgshare}/help

      --enable-cap
      --enable-gdbm
      --enable-etcdir=/etc
      --enable-maildir-support
      --enable-multibyte
      --enable-pcre
      --enable-unicode9
      --enable-zsh-secure-free

      --disable-dynamic

      --enable-zpython
      --with-python-config-dir=#{python.opt_prefix}/Frameworks/Python.framework/Versions/Current/lib/python#{python_version}/config-#{python_version}-darwin
      --with-python-executable=#{python.bin}/python#{python_version}
      --with-python-version=#{python_version}
      --with-tcsetpgrp
      --with-term-lib=ncursesw
    ]

    system "./configure", *args

    # system "./configure", "--prefix=#{prefix}",
    #        "--enable-fndir=#{pkgshare}/functions",
    #        "--enable-scriptdir=#{pkgshare}/scripts",
    #        "--enable-site-fndir=#{HOMEBREW_PREFIX}/share/zsh/site-functions",
    #        "--enable-site-scriptdir=#{HOMEBREW_PREFIX}/share/zsh/site-scripts",
    #        "--enable-runhelpdir=#{pkgshare}/help",
    #        "--enable-cap",
    #        "--enable-maildir-support",
    #        "--enable-multibyte",
    #        "--enable-pcre",
    #        "--enable-zsh-secure-free",
    #        "--enable-unicode9",
    #        "--enable-etcdir=/etc",
    #        "--with-tcsetpgrp",
    #        "DL_EXT=bundle"

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
    inreplace "config.modules", "name=zsh/net/tcp modfile=Src/Modules/tcp.mdd link=no auto=no load=no", "name=zsh/net/tcp modfile=Src/Modules/tcp.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/termcap modfile=Src/Modules/termcap.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/terminfo modfile=Src/Modules/terminfo.mdd link=static auto=no load=yes"
    # inreplace "config.modules", "name=zsh/zftp modfile=Src/Modules/zftp.mdd link=no auto=no load=no functions=Functions/Zftp/*"
    inreplace "config.modules", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=no auto=no load=no", "name=zsh/zprof modfile=Src/Modules/zprof.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=no auto=no load=no", "name=zsh/zpty modfile=Src/Modules/zpty.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=no auto=no load=no", "name=zsh/zselect modfile=Src/Modules/zselect.mdd link=static auto=no load=yes"
    inreplace "config.modules", "name=zsh/zpython modfile=Src/Modules/zpython.mdd link=no auto=no load=no", "name=zsh/zpython modfile=Src/Modules/zpython.mdd link=static auto=no load=yes"
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

    inreplace "config.h", "#define HAVE_FACCESSX 1", "/* #undef HAVE_FACCESSX */"
    inreplace "config.h", "#define HAVE_CAP_GET_PROC 1", "/* #undef HAVE_CAP_GET_PROC */"

    inreplace "config.h", "#define DEFAULT_FCEDIT \"vi\"", "#define DEFAULT_FCEDIT \"nvim\""
    inreplace "config.h", "#define HAVE_CANONICALIZE_FILE_NAME 1", "/* #undef HAVE_CANONICALIZE_FILE_NAME */"
    inreplace "config.h", "#define HAVE_CYGWIN_CONV_PATH 1", "/* #undef HAVE_CYGWIN_CONV_PATH */"
    inreplace "config.h", "#define HAVE_GETUTENT 1", "/* #undef HAVE_GETUTENT */"
    inreplace "config.h", "#define HAVE_INITSCR 1", "/* #undef HAVE_INITSCR */"
    inreplace "config.h", "#define HAVE_NIS_LIST 1", "/* #undef HAVE_NIS_LIST */"
    inreplace "config.h", "#define HAVE_RESIZE_TERM 1", "/* #undef HAVE_RESIZE_TERM */"
    inreplace "config.h", "#define HAVE_SETPROCTITLE 1", "/* #undef HAVE_SETPROCTITLE */"
    inreplace "config.h", "#define HAVE_SETRESGID 1", "/* #undef HAVE_SETRESGID */"
    inreplace "config.h", "#define HAVE_SETRESUID 1", "/* #undef HAVE_SETRESUID */"
    inreplace "config.h", "#define HAVE_SRAND_DETERMINISTIC 1", "/* #undef HAVE_SRAND_DETERMINISTIC */"
    inreplace "config.h", "#define HAVE_WADDWSTR 1", "/* #undef HAVE_WADDWSTR */"
    inreplace "config.h", "#define HAVE_WGET_WCH 1", "/* #undef HAVE_WGET_WCH */"
    inreplace "config.h", "#define HAVE_XW 1", "/* #undef HAVE_XW */"

    system "make", "install"
    system "make", "install.info"

    # if build.head?
    #   # disable target install.man, because the required yodl comes neither with macOS nor Homebrew
    #   # also disable install.runhelp and install.info because they would also fail or have no effect
    #   system "make", "install.bin", "install.modules", "install.fns"
    # else
    #   system "make", "install"
    #   system "make", "install.info"
    #
    #   resource("htmldoc").stage do
    #     (pkgshare/"htmldoc").install Dir["Doc/*.html"]
    #   end
    # end
  end

  test do
    assert_equal "homebrew", shell_output("#{bin}/zsh -c 'echo homebrew'").chomp
    system bin/"zsh", "-c", "printf -v hello -- '%s'"
  end
end
