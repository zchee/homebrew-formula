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
      -Ofast
    ]
    if Hardware::CPU.intel?
      c_ld_flags << "-march=native"
    elsif Hardware::CPU.arm?
      c_ld_flags << "-mcpu=apple-m1"
    end
    cppflags = "-DHAVE_CONFIG_H -DHAVE_NCURSESW_CURSES_H -DHAVE_READLINE -DHAVE_PCRE2 -DPCRE2_CODE_UNIT_WIDTH=8"

    inreplace "config.make" do |s|
      s.gsub!(/CFLAGS =.*/, "CFLAGS= #{c_ld_flags.join(" ")} -I#{include} -DHAVE_EXECINFO_H")
      s.gsub!(/CPPFLAGS =.*/, "CPPFLAGS= #{cppflags}")
      s.gsub!(/LDFLAGS =.*/, "LDFLAGS= -L#{lib} \
        #{c_ld_flags.join(" ")} \
        #{Formula["libiconv"].opt_lib}/libiconv.a \
        #{Formula["readline"].opt_lib}/libreadline.a \
        #{Formula["pcre2"].opt_lib}/libpcre2-posix.a \
        #{Formula["pcre2"].opt_lib}/libpcre2-8.a \
        #{Formula["ncurses-head"].opt_lib}/libncursesw.a")
      s.gsub!(/LDLIBS =.*/, "LDLIBS=")
    end

    if Hardware::CPU.arm?
      inreplace "contrib/config.make-Darwin" do |s|
        s.gsub!(/(XML_CATALOG_FILES)=.*/, "\\1=#{etc}/xml/catalog")
        s.gsub!(/(\$\(HOMEBREW_PREFIX\)\/opt)\/ncurses/, "\\1/ncurses-head")
        # NCURSES_DIR ?= $(wildcard $(HOMEBREW_PREFIX)/opt/ncurses)
        s.gsub!(/(TIG_NCURSES) = -lncursesw/, "\\1 =")
	s.gsub!(/(TIG_LDFLAGS) \+= -L(\$\(NCURSES_DIR\)\/lib)/, "\\1 \+= \\2/libncursesw.a")
        s.gsub!(/(TIG_LDLIBS) \+= -lreadline/, "\\1 =")
        # s.gsub!(/(TIG_LDLIBS) \+= -lreadline/, "\\1 = #{Formula["readline"].opt_lib}/libreadline.a")
	s.gsub!(/(TIG_LDFLAGS) \+= -L(\$\(READLINE_DIR\)\/lib)/, "\\1 \+= \\2/libreadline.a")
        s.gsub!(/(TIG_LDLIBS) \+= -lpcre2-posix -lpcre2-8/, "\\1 =")
        # s.gsub!(/(TIG_LDLIBS) \+= -lpcre2-posix -lpcre2-8/, "\\1 = #{Formula["pcre2"].opt_lib}/libpcre2-posix.a #{Formula["pcre2"].opt_lib}/libpcre2-8.a")
	s.gsub!(/(TIG_LDFLAGS) \+= -L(\$\(PCRE2_DIR\)\/lib)/, "\\1 \+= \\2/libpcre2-posix.a \\2/libpcre2-8.a")
      end
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
