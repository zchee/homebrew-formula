class TigHead < Formula
  desc "Text interface for Git repositories"
  homepage "https://jonas.github.io/tig/"
  license "GPL-2.0-or-later"

  head do
    url "https://github.com/jonas/tig.git", branch: "master"

    depends_on "asciidoc" => :build
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "xmlto" => :build
  end

  depends_on "libiconv"
  depends_on "ncurses-head"
  depends_on "pcre2"
  depends_on "readline"

  def install
    system "./autogen.sh" if build.head?
    system "./configure", "--prefix=#{prefix}", "--sysconfdir=#{etc}"

    c_ld_flags = %W[
      -march=native
      -Ofast
    ]
    cppflags = "-DHAVE_CONFIG_H -DHAVE_NCURSESW_CURSES_H -DHAVE_READLINE -DHAVE_PCRE2 -DPCRE2_CODE_UNIT_WIDTH=8"

    inreplace "config.make", /CFLAGS =.*/, "CFLAGS= #{c_ld_flags.join(" ")} -I#{include} -DHAVE_EXECINFO_H"
    inreplace "config.make", /CPPFLAGS =.*/, "CPPFLAGS= #{cppflags}"
    inreplace "config.make", /LDFLAGS =.*/, "LDFLAGS= -L#{lib} \
      #{c_ld_flags.join(" ")} \
      #{Formula["libiconv"].opt_lib}/libiconv.a \
      #{Formula["readline"].opt_lib}/libreadline.a \
      #{Formula["pcre2"].opt_lib}/libpcre2-posix.a \
      #{Formula["pcre2"].opt_lib}/libpcre2-8.a \
      #{Formula["ncurses-head"].opt_lib}/libncursesw.a"
    inreplace "config.make", /LDLIBS =.*/, "LDLIBS="

    if Hardware::CPU.arm?
      inreplace "contrib/config.make-Darwin", /(XML_CATALOG_FILES)=.*/, "\\1=#{etc}/xml/catalog"
      inreplace "contrib/config.make-Darwin", /(\$\(HOMEBREW_PREFIX\)\/opt)\/ncurses/, "\\1/ncurses-head"
      inreplace "contrib/config.make-Darwin", /(TIG_NCURSES) = -lncursesw/, "\\1 ="
      inreplace "contrib/config.make-Darwin", /(TIG_LDFLAGS) \+= -L(\$\(NCURSES_DIR\)\/lib)/, "\\1 \+= \\2/libncursesw.a"
      inreplace "contrib/config.make-Darwin", /(TIG_LDLIBS) \+= -lreadline/, "\\1 ="
      inreplace "contrib/config.make-Darwin", /(TIG_LDFLAGS) \+= -L(\$\(READLINE_DIR\)\/lib)/, "\\1 \+= \\2/libreadline.a"
      inreplace "contrib/config.make-Darwin", /(TIG_LDLIBS) \+= -lpcre2-posix -lpcre2-8/, "\\1 ="
      inreplace "contrib/config.make-Darwin", /(TIG_LDFLAGS) \+= -L(\$\(PCRE2_DIR\)\/lib)/, "\\1 \+= \\2/libpcre2-posix.a \\2/libpcre2-8.a"
    end

    system "make"
    # Ensure the configured `sysconfdir` is used during runtime by
    # installing in a separate step.
    system "make", "install", "sysconfdir=#{pkgshare}/examples"
    system "make", "install-doc-man"

    # comment out since git bash completion better than tig bash completion
    # bash_completion.install "contrib/tig-completion.bash"
    # zsh_completion.install "contrib/tig-completion.zsh" => "_tig"
    # cp "#{bash_completion}/tig-completion.bash", zsh_completion
  end

  def caveats
    <<~EOS
      A sample of the default configuration has been installed to:
        #{opt_pkgshare}/examples/tigrc
      to override the system-wide default configuration, copy the sample to:
        #{etc}/tigrc
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tig -v")
  end
end
