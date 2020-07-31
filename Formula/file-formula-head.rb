# "File" is a reserved class name
class FileFormulaHead < Formula
  desc "Utility to determine file types"
  homepage "https://www.darwinsys.com/file/"
  head "https://github.com/file/file.git"

  keg_only :provided_by_macos

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "libmagic" => :build
  depends_on "zlib" => :build
  depends_on "xz" => :build

  def install
    ENV.prepend "LDFLAGS", "-L#{Formula["libmagic"].opt_lib} -lmagic"

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --enable-static
      --enable-shared
    ]

    system "autoreconf", "-ivf"

    inreplace "src/Makefile.in", "file_DEPENDENCIES = libmagic.la", ""
    inreplace "src/Makefile.in", "file_LDADD = libmagic.la", "file_LDADD = $(LDADD)"

    system "./configure", *args

    system "make", "install-exec"
    system "make", "-C", "doc", "install-man1"
  end

  test do
    system "#{bin}/file", test_fixtures("test.mp3")
  end
end
