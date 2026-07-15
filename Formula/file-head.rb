class FileHead < Formula
  desc "Utility to determine file types"
  homepage "https://darwinsys.com/file/"
  license "BSD-2-Clause-Darwin"

  livecheck do
    url :stable
    regex(/href=.*?file[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  head do
    url "https://github.com/file/file.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  keg_only :shadowed_by_macos, "macOS provides"

  depends_on "bzip2" => :build
  depends_on "libmagic-head" => :build
  depends_on "lrzip" => :build
  depends_on "lzlib" => :build
  depends_on "xz" => :build
  depends_on "zlib" => :build
  depends_on "zstd" => :build

  def install
    ENV.prepend "LDFLAGS", "-L#{formula_opt_lib("libmagic-head")} -lmagic"

    system "autoreconf", "-fiv"

    inreplace "src/Makefile.in" do |s|
      s.gsub! "file_DEPENDENCIES = libmagic.la", ""
      s.gsub! "libmagic.la -lm", "$(LDADD) -lm"
    end

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-bzlib",
                          "--enable-lrziplib",
                          "--enable-lz4lib",
                          "--enable-lzlib",
                          "--enable-xzlib",
                          "--enable-zlib",
                          "--enable-zstdlib",
                          "--enable-fsect-man5",
                          "--disable-year2038"
    system "make", "install-exec"
    system "make", "-C", "doc", "install-man1"
    rm_r lib
  end

  test do
    system "#{bin}/file", test_fixtures("test.mp3")
  end
end
