class GitHead < Formula
  desc "Distributed revision control system"
  homepage "https://git-scm.com"
  head "https://github.com/git/git.git", shallow: false

  livecheck do
    url "https://www.kernel.org/pub/software/scm/git/"
    regex(/href=.*?git[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "asciidoc"
  depends_on "brotli"
  depends_on "c-ares"
  depends_on "curl-quic"
  depends_on "gettext"
  depends_on "libidn2"
  depends_on "libmetalink"
  depends_on "libssh2"
  depends_on "nghttp2"
  depends_on "nghttp3"
  depends_on "ngtcp2"
  depends_on "openldap"
  depends_on "openssl-quic"
  depends_on "pcre2"
  depends_on "rtmpdump"
  depends_on "xmlto"
  depends_on "zlib"
  depends_on "zstd"

  resource "html" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-htmldocs-2.29.2.tar.xz"
    sha256 "f7c762cc5c8c5230885b76134cbc801f6149c29c812d3f276ff1914176a7dab8"
  end

  resource "man" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-manpages-2.29.2.tar.xz"
    sha256 "e2d44a2a30b9d43a770262f1328b77df2f532f16c2dcd235655e5c9bd39bd792"
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

    ENV["CFLAGS"] = "-march=native -Ofast -flto -std=c17"
    ENV["CXXFLAGS"] = "-march=native -Ofast -flto -std=c++17 -stdlib=libc++"
    ENV["LDFLAGS"] = "-march=native -Ofast -flto"
    ENV["LDFLAGS"] += " -L#{Formula["brotli"].lib} -L#{Formula["c-ares"].lib} -L#{Formula["curl-quic"].lib} -L#{Formula["libidn2"].lib} -L#{Formula["libmetalink"].lib}"
    ENV["LDFLAGS"] += " -L#{Formula["libssh2"].lib} -L#{Formula["nghttp2"].lib} -L#{Formula["nghttp3"].lib} -L#{Formula["ngtcp2"].lib} -L#{Formula["openldap"].lib}"
    ENV["LDFLAGS"] += " -L#{Formula["openssl-quic"].lib} -L#{Formula["pcre2"].lib} -L#{Formula["rtmpdump"].lib} -L#{Formula["zlib"].lib} -L#{Formula["zstd"].lib}"
    ENV["XML_CATALOG_FILES"] = "/usr/local/etc/xml/catalog"

    perl_version = Utils.safe_popen_read("perl", "--version")[/v(\d+\.\d+)(?:\.\d+)?/, 1]

    ENV["PERLLIB_EXTRA"] = %W[
      #{MacOS.active_developer_dir}
      /Library/Developer/CommandLineTools
      /Applications/Xcode.app/Contents/Developer
    ].uniq.map do |p|
      "#{p}/Library/Perl/#{perl_version}/darwin-thread-multi-2level"
    end.join(":")

    # Ensure we are using the correct system headers (for curl) to workaround
    # mismatched Xcode/CLT versions:
    # https://github.com/Homebrew/homebrew-core/issues/46466
    if MacOS.version == :mojave && MacOS::CLT.installed? && MacOS::CLT.provides_sdk?
      ENV["HOMEBREW_SDKROOT"] = MacOS::CLT.sdk_path(MacOS.version)
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

    openssl_prefix = Formula["openssl-quic"].opt_prefix
    args += %W[NO_APPLE_COMMON_CRYPTO=1 OPENSSLDIR=#{openssl_prefix}]

    system "make", "install", *args

    git_core = libexec/"git-core"

    # Install the macOS keychain credential helper
    cd "contrib/credential/osxkeychain" do
      system "make", "CC=#{ENV.cc}",
                     "CFLAGS=#{ENV.cflags}",
                     "LDFLAGS=#{ENV.ldflags}"
      git_core.install "git-credential-osxkeychain"
      system "make", "clean"
    end

    # Generate diff-highlight perl script executable
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

    elisp.install Dir["contrib/emacs/*.el"]
    (share/"git-core").install "contrib"

    # We could build the manpages ourselves, but the build process depends
    # on many other packages, and is somewhat crazy, this way is easier.
    man.install resource("man")
    (share/"doc/git-doc").install resource("html")

    # Make html docs world-readable
    chmod 0644, Dir["#{share}/doc/git-doc/**/*.{html,txt}"]
    chmod 0755, Dir["#{share}/doc/git-doc/{RelNotes,howto,technical}"]

    # git-send-email needs Net::SMTP::SSL
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
    (buildpath/"gitconfig").write <<~EOS
      [credential]
      \thelper = osxkeychain
    EOS
    etc.install "gitconfig"
  end

  def caveats
    <<~EOS
      The Tcl/Tk GUIs (e.g. gitk, git-gui) are now in the `git-gui` formula.
    EOS
  end

  test do
    system bin/"git", "init"
    %w[haunted house].each { |f| touch testpath/f }
    system bin/"git", "add", "haunted", "house"
    system bin/"git", "config", "user.name", "'A U Thor'"
    system bin/"git", "config", "user.email", "author@example.com"
    system bin/"git", "commit", "-a", "-m", "Initial Commit"
    assert_equal "haunted\nhouse", shell_output("#{bin}/git ls-files").strip

    # Check Net::SMTP::SSL was installed correctly.
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
