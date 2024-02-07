class GitHead < Formula
  desc "Distributed revision control system"
  homepage "https://git-scm.com"
  license "GPL-2.0-only"
  head "https://github.com/git/git.git", branch: "master"

  livecheck do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/"
    regex(/href=.*?git[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "asciidoc"
  depends_on "brotli"
  depends_on "c-ares"
  depends_on "curl"
  depends_on "gettext"
  depends_on "libidn2"
  depends_on "libmetalink"
  depends_on "libssh2"
  depends_on "nghttp2"
  depends_on "nghttp3"
  depends_on "ngtcp2"
  depends_on "openldap"
  depends_on "pcre2"
  depends_on "rtmpdump"
  depends_on "xmlto"
  depends_on "zlib"
  depends_on "zstd"

  uses_from_macos "expat"

  on_linux do
    depends_on "linux-headers@5.15" => :build
    depends_on "openssl@1.1" # Uses CommonCrypto on macOS
  end

  resource "html" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-htmldocs-2.43.0.tar.xz"
    sha256 "8b02e46a5fb41971be8cd2347dbc14d53802a08b0822adc1f822831da8f31f60"
  end

  resource "man" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-manpages-2.43.0.tar.xz"
    sha256 "ef18df09444a60c70be996a481fde093928996055f61a585e9ea07b5bdc6d4d8"
  end

  resource "Net::SMTP::SSL" do
    url "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/Net-SMTP-SSL-1.04.tar.gz"
    sha256 "7b29c45add19d3d5084b751f7ba89a8e40479a446ce21cfd9cc741e558332a00"
  end

  def install
    # If these things are installed, tell Git build system not to use them
    ENV["NO_FINK"] = "1"
    ENV["NO_DARWIN_PORTS"] = "1"
    ENV["PYTHON_PATH"] = which("python")
    ENV["PERL_PATH"] = which("perl")
    ENV["USE_LIBPCRE2"] = "1"
    ENV["INSTALL_SYMLINKS"] = "1"
    ENV["LIBPCREDIR"] = Formula["pcre2"].opt_prefix
    ENV["V"] = "1" # build verbosely

    cflags = "-std=c11 -march=native -Ofast -flto"
    cxxflags = "-std=c++17 -stdlib=libc++ -march=native -Ofast -flto"
    ldflags = "-march=native -Ofast -flto"
    ldflags += " -L#{Formula["brotli"].opt_lib} -L#{Formula["c-ares"].opt_lib} -L#{Formula["curl-quic"].opt_lib} -L#{Formula["libidn2"].opt_lib}"
    ldflags += " -L#{Formula["libmetalink"].opt_lib} -L#{Formula["libssh2"].opt_lib} -L#{Formula["nghttp2"].opt_lib} -L#{Formula["nghttp3"].opt_lib} -L#{Formula["ngtcp2"].opt_lib}"
    ldflags += " -L#{Formula["openldap"].opt_lib} -L#{Formula["pcre2"].opt_lib} -L#{Formula["rtmpdump"].opt_lib}"
    ldflags += " -L#{Formula["zlib"].opt_lib} -L#{Formula["zstd"].opt_lib}"
    ENV.append "CFLAGS", *cflags
    ENV.append "CXXFLAGS", *cxxflags
    ENV.append "LDFLAGS", *ldflags

    perl_version = Utils.safe_popen_read("perl", "--version")[/v(\d+\.\d+)(?:\.\d+)?/, 1]

    if OS.mac?
      ENV["PERLLIB_EXTRA"] = %W[
        #{MacOS.active_developer_dir}
        /Library/Developer/CommandLineTools
        /Applications/Xcode.app/Contents/Developer
      ].uniq.map do |p|
        "#{p}/Library/Perl/#{perl_version}/darwin-thread-multi-2level"
      end.join(":")
    end

    # The git-gui and gitk tools are installed by a separate formula (git-gui)
    # to avoid a dependency on tcl-tk and to avoid using the broken system
    # tcl-tk (see https://github.com/Homebrew/homebrew-core/issues/36390)
    # This is done by setting the NO_TCLTK make variable.
    args = %W[
      prefix=#{prefix}
      sysconfdir=#{etc}
      CC=#{ENV.cc}
      CFLAGS=#{ENV.cflags}
      LDFLAGS=#{ENV.ldflags}
      NO_TCLTK=1
    ]

    args += if OS.mac?
      %w[NO_OPENSSL=1 APPLE_COMMON_CRYPTO=1]
    else
      openssl_prefix = Formula["openssl@1.1"].opt_prefix

      %W[NO_APPLE_COMMON_CRYPTO=1 OPENSSLDIR=#{openssl_prefix}]
    end

    # Make sure `git` looks in `opt_prefix` instead of the Cellar.
    # Otherwise, Cellar references propagate to generated plists from `git maintenance`.
    inreplace "Makefile", /(-DFALLBACK_RUNTIME_PREFIX=")[^"]+/, "\\1#{opt_prefix}"

    system "make", "install", *args

    git_core = libexec/"git-core"
    rm git_core/"git-svn"

    # Install the macOS keychain credential helper
    if OS.mac?
      cd "contrib/credential/osxkeychain" do
        system "make", "CC=#{ENV.cc}",
                       "CFLAGS=#{ENV.cflags}",
                       "LDFLAGS=#{ENV.ldflags}"
        git_core.install "git-credential-osxkeychain"
        system "make", "clean"
      end
    end

    # Generate and instal diff-highlight perl script executable
    cd "contrib/diff-highlight" do
      system "make"
      inreplace "diff-highlight", "/usr/bin/perl", "/usr/bin/env perl"
      git_core.install "diff-highlight"
    end

    # Install the netrc credential helper
    cd "contrib/credential/netrc" do
      system "make", "test"
      git_core.install "git-credential-netrc"
    end

    # Install git-subtree
    cd "contrib/subtree" do
      system "make", "CC=#{ENV.cc}",
                     "CFLAGS=#{ENV.cflags}",
                     "LDFLAGS=#{ENV.ldflags}"
      git_core.install "git-subtree"
    end

    # install the completion script first because it is inside "contrib"
    bash_completion.install "contrib/completion/git-completion.bash"
    bash_completion.install "contrib/completion/git-prompt.sh"
    zsh_completion.install "contrib/completion/git-completion.zsh" => "_git"
    cp "#{bash_completion}/git-completion.bash", zsh_completion

    (share/"git-core").install "contrib"

    # We could build the manpages ourselves, but the build process depends
    # on many other packages, and is somewhat crazy, this way is easier.
    man.install resource("man")
    (share/"doc/git-doc").install resource("html")

    # Make html docs world-readable
    chmod 0644, Dir["#{share}/doc/git-doc/**/*.{html,txt}"]
    chmod 0755, Dir["#{share}/doc/git-doc/{RelNotes,howto,technical}"]

    # git-send-email needs Net::SMTP::SSL or Net::SMTP >= 2.34
    resource("Net::SMTP::SSL").stage do
      (share/"perl5").install "lib/Net"
    end

    # This is only created when building against system Perl, but it isn't
    # purged by Homebrew's post-install cleaner because that doesn't check
    # "Library" directories. It is however pointless to keep around as it
    # only contains the perllocal.pod installation file.
    rm_rf prefix/"Library/Perl"

    # Set the macOS keychain credential helper by default
    # (as Apple's CLT's git also does this).
    if OS.mac?
      (buildpath/"gitconfig").write <<~EOS
        [credential]
        \thelper = osxkeychain
      EOS
      etc.install "gitconfig"
    end
  end

  def caveats
    <<~EOS
      The Tcl/Tk GUIs (e.g. gitk, git-gui) are now in the `git-gui` formula.
      Subversion interoperability (git-svn) is now in the `git-svn` formula.
    EOS
  end

  test do
    assert_equal version, resource("html").version, "`html` resource needs updating!"
    assert_equal version, resource("man").version, "`man` resource needs updating!"

    system bin/"git", "init"
    %w[haunted house].each { |f| touch testpath/f }
    system bin/"git", "add", "haunted", "house"
    system bin/"git", "config", "user.name", "'A U Thor'"
    system bin/"git", "config", "user.email", "author@example.com"
    system bin/"git", "commit", "-a", "-m", "Initial Commit"
    assert_equal "haunted\nhouse", shell_output("#{bin}/git ls-files").strip

    # Check Net::SMTP or Net::SMTP::SSL works for git-send-email
    if OS.mac?
      %w[foo bar].each { |f| touch testpath/f }
      system bin/"git", "add", "foo", "bar"
      system bin/"git", "commit", "-a", "-m", "Second Commit"
      assert_match "Authentication Required", pipe_output(
        "#{bin}/git send-email --from=test@example.com --to=dev@null.com " \
        "--smtp-server=smtp.gmail.com --smtp-server-port=587 " \
        "--smtp-encryption=tls --confirm=never HEAD^ 2>&1",
      )
    end
  end
end
