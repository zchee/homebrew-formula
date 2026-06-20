class ZshHead < Formula
  desc "UNIX shell (command interpreter)"
  homepage "https://www.zsh.org/"
  license all_of: [
    "MIT-Modern-Variant",
    "GPL-2.0-only", # Completion/Linux/Command/_qdbus, Completion/openSUSE/Command/{_osc,_zypper}
    "GPL-2.0-or-later", # Completion/Unix/Command/_darcs
    "ISC", # Src/openssh_bsd_setres_id.c
  ]

  head do
    url "https://github.com/zsh-users/zsh.git", branch: "master"
    depends_on "autoconf" => :build
    depends_on "gdbm" => :build
    depends_on "groff" => :build
    depends_on "libiconv" => :build
    depends_on "yodl" => :build
  end

  depends_on "ncurses-head" => :build
  depends_on "pcre2" => :build

  on_system :linux, macos: :ventura_or_newer do
    depends_on "texinfo" => :build
  end

  # OpenAI Codex shell escalation wrapper
  # https://github.com/openai/codex/tree/main/codex-rs/shell-escalation
  patch :DATA

  # macOS 26 Tahoe FD_SET overflow EXC_GUARD guard
  patch do
    url "https://raw.githubusercontent.com/zchee/homebrew-formula/refs/heads/main/Formula/patches/zsh-fdset-overflow-macos26.patch"
    sha256 "e4026cafc16cd7e1b56240f0f6d6aaaa53f25c163fd486b48b4cf2dc683c283b"
  end

  def install
    # Fix compile with newer Clang. Remove in the next release
    # Ref: https://sourceforge.net/p/zsh/code/ci/ab4d62eb975a4c4c51dd35822665050e2ddc6918/
    ENV.append_to_cflags "-Wno-implicit-int" if DevelopmentTools.clang_build_version >= 1403

    if Hardware::CPU.intel?
      cflags  = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      ldflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    else
      cpu = `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`.chomp
      cflags  = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      ldflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    end
    cppflags = "-D_DARWIN_C_SOURCE -D_POSIX_C_SOURCE=200809L " "-I#{Formula["ncurses-head"].opt_include}/ncursesw"
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags
    ENV.append "CPPFLAGS", *cppflags

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
           "--enable-unicode9",
           "--disable-etcdir",
           "--disable-dynamic",
           "--enable-year2038"

    # Do not version installation directories.
    inreplace ["Makefile", "Src/Makefile"],
              "$(libdir)/$(tzsh)/$(VERSION)", "$(libdir)"

    inreplace "config.modules", "link=no", "link=static"
    inreplace "config.modules", "auto=yes", "auto=no"
    inreplace "config.modules", "load=no", "load=yes"

    system "cat", "config.modules"

    system "make", "html"
    system "make", "install.bin", "install.modules", "install.fns", "install.man", "install.html"
  end

  test do
    assert_equal "homebrew", shell_output("#{bin}/zsh -c 'echo homebrew'").chomp
    system bin/"zsh", "-c", "printf -v hello -- '%s'"
  end
end

__END__
diff --git a/Src/exec.c b/Src/exec.c
index 2c730b910..8e10e09f5 100644
--- a/Src/exec.c
+++ b/Src/exec.c
@@ -505,7 +505,9 @@ zexecve(char *pth, char **argv, char **newenvp)
 {
     int eno;
     static char buf[PATH_MAX * 2+2+1+1]; /* enough room if pwd fits in PATH_MAX */
-    char **eep;
+    char **eep, **exec_argv;
+    char *orig_pth = pth;
+    char *exec_wrapper;
 
     unmetafy(pth, NULL);
     for (eep = argv; *eep; eep++)
@@ -525,8 +527,16 @@ zexecve(char *pth, char **argv, char **newenvp)
 
     if (newenvp == NULL)
 	    newenvp = environ;
+	    exec_argv = argv;
+	    if ((exec_wrapper = getenv("EXEC_WRAPPER")) &&*exec_wrapper && !inblank(*exec_wrapper)) {
+		    exec_argv = argv - 2;
+		    exec_argv[0] = exec_wrapper;
+		    exec_argv[1] = orig_pth;
+		    pth = exec_wrapper;
+	    }
     winch_unblock();
-    execve(pth, argv, newenvp);
+    execve(pth, exec_argv, newenvp);
+    pth = orig_pth;
 
     /* If the execve returns (which in general shouldn't happen),   *
      * then check for an errno equal to ENOEXEC.  This errno is set *
