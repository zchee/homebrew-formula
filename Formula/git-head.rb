class GitHead < Formula
  desc "Distributed revision control system"
  homepage "https://git-scm.com"
  license all_of: [
    "GPL-2.0-only",
    "GPL-2.0-or-later",  # imap-send.c; trace.c; ...
    "LGPL-2.1-or-later", # xdiff/
    "BSD-3-Clause",      # xdiff/xhistogram.c; reftable/
    "MIT",               # khash.h; sha1dc/
  ]
  head "https://github.com/git/git.git", branch: "master"

  livecheck do
    url :stable
    regex(/href=.*?git[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "asciidoc" => :build
  depends_on "brotli" => :build
  depends_on "c-ares" => :build
  depends_on "curl" => :build
  depends_on "libidn2" => :build
  depends_on "libmetalink" => :build
  depends_on "libnghttp2" => :build
  depends_on "libssh2" => :build
  depends_on "openldap" => :build
  depends_on "pcre2" => :build
  depends_on "rtmpdump" => :build
  depends_on "rust" => :build
  depends_on "xmlto" => :build
  depends_on "zlib" => :build
  depends_on "zstd" => :build

  uses_from_macos "expat"
  uses_from_macos "krb5"

  on_linux do
    depends_on "openssl@3" # for git-imap-send (GPL-2.0-or-later), uses CommonCrypto on macOS
    depends_on "zlib-ng-compat"
  end

  resource "Authen::SASL" do
    url "https://cpan.metacpan.org/authors/id/E/EH/EHUELS/Authen-SASL-2.2000.tar.gz"
    sha256 "8cdf5a7f185448b614471675dae5b26f8c6e330b62264c3ff5d91172d6889b99"
  end

  resource "html" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-htmldocs-2.55.0.tar.xz"
    sha256 "d1142c4e28b469d297d6df6519653e92a76c952f55202fde17a72a3b03d49437"

    livecheck do
      formula :parent
    end
  end

  resource "man" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-manpages-2.55.0.tar.xz"
    sha256 "a32d432f80df46a14a05d1104c72d5a13fe27e9feba9aa0f017e54131db6b982"

    livecheck do
      formula :parent
    end
  end

  resource "Net::SMTP::SSL" do
    url "https://cpan.metacpan.org/authors/id/R/RJ/RJBS/Net-SMTP-SSL-1.04.tar.gz"
    sha256 "7b29c45add19d3d5084b751f7ba89a8e40479a446ce21cfd9cc741e558332a00"
  end

  deny_network_access! [:build, :postinstall]

  def install
    odie "html resource needs to be updated" if build.stable? && version != resource("html").version
    odie "man resource needs to be updated" if build.stable? && version != resource("man").version

    # If these things are installed, tell Git build system not to use them
    ENV["NO_FINK"] = "1"
    ENV["NO_DARWIN_PORTS"] = "1"
    ENV["PYTHON_PATH"] = which("python")
    ENV["PERL_PATH"] = which("perl")
    ENV["USE_LIBPCRE2"] = "1"
    ENV["INSTALL_SYMLINKS"] = "1"
    ENV["LIBPCREDIR"] = formula_opt_prefix("pcre2")
    ENV["V"] = "1" # build verbosely

    if Hardware::CPU.intel?
      cflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      cxxflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c++20"
      ldflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    else
      cpu = `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`.chomp
      cflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      cxxflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c++20"
      ldflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    end
    ldflags += " -L#{formula_opt_lib("brotli")} -L#{formula_opt_lib("c-ares")} -L#{formula_opt_lib("curl")}"
    ldflags += " -L#{formula_opt_lib("libidn2")} -L#{formula_opt_lib("libmetalink")} -L#{formula_opt_lib("libssh2")}"
    ldflags += " -L#{formula_opt_lib("libnghttp2")} -L#{formula_opt_lib("nghttp3")} -L#{formula_opt_lib("ngtcp2")}"
    ldflags += " -L#{formula_opt_lib("openldap")} -L#{formula_opt_lib("pcre2")} -L#{formula_opt_lib("rtmpdump")}"
    ldflags += " -L#{formula_opt_lib("zlib")} -L#{formula_opt_lib("zstd")}"
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
      openssl_prefix = formula_opt_prefix("openssl@3")

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
                       "CXXFLAGS=#{ENV.cxxflags}",
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
                     "CXXFLAGS=#{ENV.cxxflags}",
                     "LDFLAGS=#{ENV.ldflags}"
      git_core.install "git-subtree"
    end

    # Install git-jump
    cd "contrib/git-jump" do
      git_core.install "git-jump"
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

    resource("Authen::SASL").stage do
      (share/"perl5").install "lib/Authen"
    end

    # This is only created when building against system Perl, but it isn't
    # purged by Homebrew's post-install cleaner because that doesn't check
    # "Library" directories. It is however pointless to keep around as it
    # only contains the perllocal.pod installation file.
    perl_dir = prefix/"Library/Perl"
    rm_r perl_dir if perl_dir.exist?

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
    system bin/"git", "init"
    %w[haunted house].each { |f| touch testpath/f }
    system bin/"git", "add", "haunted", "house"
    system bin/"git", "config", "user.name", "'A U Thor'"
    system bin/"git", "config", "user.email", "author@example.com"
    system bin/"git", "commit", "-a", "-m", "Initial Commit"
    assert_equal "haunted\nhouse", shell_output("#{bin}/git ls-files").strip

    # Check that our `inreplace` for the `Makefile` does not break.
    # If this assertion fails, please fix the `inreplace` instead of removing this test.
    # The failure of this test means that `git` will generate broken launchctl plist files.
    refute_match HOMEBREW_CELLAR.to_s, shell_output("#{bin}/git --exec-path")

    return unless OS.mac?

    # Check Net::SMTP or Net::SMTP::SSL works for git-send-email
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
