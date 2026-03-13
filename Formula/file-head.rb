class FileHead < Formula
  desc "Utility to determine file types"
  homepage "https://darwinsys.com/file/"
  license "BSD-2-Clause-Darwin"
  head do
    url "https://github.com/file/file.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  livecheck do
    url "https://astron.com/pub/file/"
    regex(/href=.*?file[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "libmagic-head"
  depends_on "zlib"
  depends_on "bzip2"
  depends_on "xz"
  depends_on "zstd"
  depends_on "lzlib"

  def install
    ENV.prepend "LDFLAGS", "-L#{Formula["libmagic-head"].opt_lib} -lmagic"

    system "autoreconf", "-fiv"

    inreplace "src/Makefile.in" do |s|
      s.gsub! "file_DEPENDENCIES = libmagic.la", ""
      s.gsub! "libmagic.la -lm", "$(LDADD) -lm"
    end

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-zlib",
                          "--enable-bzlib",
                          "--enable-xzlib",
                          "--enable-zstdlib",
                          "--enable-lzlib"
    system "make", "install-exec"
    system "make", "-C", "doc", "install-man1"
    rm_r lib
  end

  test do
    system "#{bin}/file", test_fixtures("test.mp3")
  end
end
