class GitHead < Formula
  desc "Distributed revision control system"
  homepage "https://git-scm.com"
  head "https://github.com/git/git.git", :shallow => false

  depends_on "brotli"
  depends_on "curl-head"
  depends_on "gettext"
  depends_on "libidn2"
  depends_on "libmetalink"
  depends_on "libssh2"
  depends_on "nghttp2"
  depends_on "pcre2"
  depends_on "rtmpdump"
  depends_on "zlib"
  depends_on "asciidoc"
  depends_on "xmlto"

  if MacOS.version < :yosemite
    depends_on "openssl@1.1"
    depends_on "curl"
  end

  resource "html" do
    url "https://www.kernel.org/pub/software/scm/git/git-htmldocs-2.26.0.tar.xz"
    sha256 "5be14d0835177f8ada0310c98b0248c7caaea0a302b7b58f1ccc0c0f7ece2466"
  end

  resource "man" do
    url "https://www.kernel.org/pub/software/scm/git/git-manpages-2.26.0.tar.xz"
    sha256 "387e46a0b67c148be7ef80759b1930a3b64ac77782630c18afc784f35ed93426"
  end

  resource "Net::SMTP::SSL" do
    url "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/Net-SMTP-SSL-1.04.tar.gz"
    sha256 "7b29c45add19d3d5084b751f7ba89a8e40479a446ce21cfd9cc741e558332a00"
  end

  def install
    ENV["CFLAGS"] = "-std=c17 -march=native -Ofast -flto"
    ENV["LDFLAGS"] = "-march=native -Ofast -flto -L#{Formula["zlib"].lib} -L#{Formula["brotli"].lib} -L#{Formula["libressl"].lib} -L#{Formula["libmetalink"].lib} -L#{Formula["libssh2"].lib} -L#{Formula["rtmpdump"].lib} -L#{Formula["libidn2"].lib} -L#{Formula["nghttp2"].lib}"
    # If these things are installed, tell Git build system not to use them
    ENV["NO_FINK"] = "1"
    ENV["NO_DARWIN_PORTS"] = "1"
    ENV["NO_R_TO_GCC_LINKER"] = "1" # pass arguments to LD correctly
    ENV["PYTHON_PATH"] = which("python")
    ENV["PERL_PATH"] = which("perl")
    ENV["USE_LIBPCRE2"] = "1"
    ENV["INSTALL_SYMLINKS"] = "1"
    ENV["LIBPCREDIR"] = Formula["pcre2"].opt_prefix
    ENV["CURLDIR"] = Formula["curl-head"].opt_prefix
    ENV["V"] = "1" # build verbosely
    ENV["JAVA_HOME"] = "/Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home"
    ENV["XML_CATALOG_FILES"] = "/usr/local/etc/xml/catalog"

    perl_version = Utils.popen_read("perl --version")[/v(\d+\.\d+)(?:\.\d+)?/, 1]

    ENV["PERLLIB_EXTRA"] = %W[
      #{MacOS.active_developer_dir}
      /Library/Developer/CommandLineTools
      /Applications/Xcode.app/Contents/Developer
    ].uniq.map do |p|
      "#{p}/Library/Perl/#{perl_version}/darwin-thread-multi-2level"
    end.join(":")

    ENV["NO_PERL_MAKEMAKER"] = "1" unless quiet_system ENV["PERL_PATH"], "-e", "use ExtUtils::MakeMaker"

    # Ensure we are using the correct system headers (for curl) to workaround
    # mismatched Xcode/CLT versions:
    # https://github.com/Homebrew/homebrew-core/issues/46466
    if MacOS.version == :mojave && MacOS::CLT.installed? && MacOS::CLT.provides_sdk?
      ENV["HOMEBREW_SDKROOT"] = MacOS::CLT.sdk_path(MacOS.version)
    end

    args = %W[
      prefix=#{prefix}
      sysconfdir=#{etc}
      CC=#{ENV.cc}
      CFLAGS=#{ENV.cflags}
      LDFLAGS=#{ENV.ldflags}
    ]

    if MacOS.version < :yosemite
      openssl_prefix = Formula["openssl"].opt_prefix
      args += %W[NO_APPLE_COMMON_CRYPTO=1 OPENSSLDIR=#{openssl_prefix}]
    else
      args += %w[NO_OPENSSL=1 APPLE_COMMON_CRYPTO=1]
    end

    system "make", "install", "install-man", *args

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

    # To avoid this feature hooking into the system OpenSSL, remove it
    rm "#{libexec}/git-core/git-imap-send" if MacOS.version >= :yosemite

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
    system bin/"git", "commit", "-a", "-m", "Initial Commit"
    assert_equal "haunted\nhouse", shell_output("#{bin}/git ls-files").strip

    # Check Net::SMTP::SSL was installed correctly.
    %w[foo bar].each { |f| touch testpath/f }
    system bin/"git", "add", "foo", "bar"
    system bin/"git", "commit", "-a", "-m", "Second Commit"
    assert_match "Authentication Required", shell_output(
      "#{bin}/git send-email --to=dev@null.com --smtp-server=smtp.gmail.com " \
      "--smtp-encryption=tls --confirm=never HEAD^ 2>&1", 255
    )
  end
end
