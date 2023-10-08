class ManDbHead < Formula
  desc "Unix documentation system"
  homepage "https://www.nongnu.org/man-db/"
  license "GPL-2.0-or-later"

  livecheck do
    url "https://download.savannah.gnu.org/releases/man-db/"
    regex(/href=.*?man-db[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "pkg-config" => :build
  depends_on "groff"
  depends_on "libpipeline"

  uses_from_macos "zlib"

  on_linux do
    depends_on "gdbm"
  end

  head do
    url "https://gitlab.com/man-db/man-db.git", branch: "main"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "bzip2" => :build
    depends_on "gdbm" => :build
    depends_on "gettext" => :build
    depends_on "groff" => :build
    depends_on "gzip" => :build
    depends_on "libtool" => :build
    depends_on "lzip" => :build
    depends_on "xz" => :build
    depends_on "zstd" => :build
  end

  def install
    man_db_conf = etc/"man_db.conf"
    args = %W[
      --disable-silent-rules
      --disable-cache-owner
      --disable-setuid
      --disable-nls
      --program-prefix=g
      --localstatedir=#{var}
      --with-config-file=#{man_db_conf}
      --with-systemdtmpfilesdir=#{etc}/tmpfiles.d
      --with-systemdsystemunitdir=#{etc}/systemd/system

      --with-db=gdbm
      --with-gzip=#{Formula["gzip"].opt_prefix}
      --with-bzip2=#{Formula["bzip2"].opt_prefix}
      --with-xz=#{Formula["xz"].opt_prefix}
      --with-lzma=#{Formula["xz"].opt_prefix}
      --with-lzip=#{Formula["lzip"].opt_prefix}
      --with-zstd=#{Formula["zstd"].opt_prefix}
    ]

    # man_db_conf = etc/"man_db.conf"
    # args = %W[
    #   --disable-silent-rules
    #   --disable-cache-owner
    #   --disable-setuid
    #   --disable-nls
    #   --program-prefix=g
    #   --localstatedir=#{var}
    #   --with-config-file=#{man_db_conf}
    #   --with-systemdtmpfilesdir=#{etc}/tmpfiles.d
    #   --with-systemdsystemunitdir=#{etc}/systemd/system
    # ]

    # man_db_conf = etc/"man_db.conf"
    # args = %W[
    #   --disable-dependency-tracking
    #   --prefix=#{prefix}
    #
    #   --disable-silent-rules
    #   --disable-cache-owner
    #   --disable-setuid
    #   --disable-nls
    #   --program-prefix=g
    #   --enable-shared
    #   --enable-static
    #   --enable-mb-groff
    #   --with-bzip2=#{Formula["bzip2"].opt_prefix}
    #   --with-xz=#{Formula["xz"].opt_prefix}
    #   --with-lzma=#{Formula["xz"].opt_prefix}
    #   --with-lzip=#{Formula["lzip"].opt_prefix}
    #   --with-zstd=#{Formula["zstd"].opt_prefix}
    #   --with-config-file=#{man_db_conf}
    #   --with-systemdtmpfilesdir=#{etc}/tmpfiles.d
    #   --with-systemdsystemunitdir=#{etc}/systemd/system
    # ]

    system "./bootstrap", "--skip-po" if build.head?
    system "./configure", *args, *std_configure_args
    system "make", "install"

    # Use Homebrew's `var` directory instead of `/var`.
    inreplace man_db_conf, "/var", var

    # Symlink commands without 'g' prefix into libexec/bin and
    # man pages into libexec/man
    %w[apropos catman lexgrog man mandb manpath whatis].each do |cmd|
      (libexec/"bin").install_symlink bin/"g#{cmd}" => cmd
    end
    (libexec/"sbin").install_symlink sbin/"gaccessdb" => "accessdb"
    %w[apropos lexgrog man manconv manpath whatis zsoelim].each do |cmd|
      (libexec/"man"/"man1").install_symlink man1/"g#{cmd}.1" => "#{cmd}.1"
    end
    (libexec/"man"/"man5").install_symlink man5/"gmanpath.5" => "manpath.5"
    %w[accessdb catman mandb].each do |cmd|
      (libexec/"man"/"man8").install_symlink man8/"g#{cmd}.8" => "#{cmd}.8"
    end

    # Symlink non-conflicting binaries and man pages
    %w[catman lexgrog mandb].each do |cmd|
      bin.install_symlink "g#{cmd}" => cmd
    end
    sbin.install_symlink "gaccessdb" => "accessdb"

    %w[accessdb catman mandb].each do |cmd|
      man8.install_symlink "g#{cmd}.8" => "#{cmd}.8"
    end
    man1.install_symlink "glexgrog.1" => "lexgrog.1"
  end

  def caveats
    <<~EOS
      Commands also provided by macOS have been installed with the prefix "g".
      If you need to use these commands with their normal names, you
      can add a "bin" directory to your PATH from your bashrc like:
        PATH="#{opt_libexec}/bin:$PATH"
    EOS
  end

  test do
    ENV["PAGER"] = "cat"
    output = shell_output("#{bin}/gman true")
    on_macos do
      assert_match "BSD General Commands Manual", output
      assert_match "The true utility always returns with exit code zero", output
    end
    on_linux do
      assert_match "true - do nothing, successfully", output
      assert_match "GNU coreutils online help: <http://www.gnu.org/software/coreutils/", output
    end
  end
end
