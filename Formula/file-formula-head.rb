# "File" is a reserved class name
class FileFormulaHead < Formula
  desc "Utility to determine file types"
  homepage "https://darwinsys.com/file/"
  # file-formula has a BSD-2-Clause-like license
  license :cannot_represent
  head "https://github.com/file/file.git", branch: "master"

  livecheck do
    url "https://astron.com/pub/file/"
    regex(/href=.*?file[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  keg_only :provided_by_macos

  depends_on "libmagic"
  depends_on "bzip2"
  depends_on "xz"
  depends_on "zlib"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build

  def install
    ENV.prepend "LDFLAGS", "-L#{Formula["libmagic"].opt_lib} -lmagic"

    system "autoreconf", "-fi"
    inreplace "src/Makefile.in" do |s|
      s.gsub! "file_DEPENDENCIES = libmagic.la", ""
      s.gsub! "file_LDADD = libmagic.la", "file_LDADD = $(LDADD)"
    end

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
    system "make", "install-exec"
    system "make", "-C", "doc", "install-man1"
    rm_r lib
  end

  test do
    system "#{bin}/file", test_fixtures("test.mp3")
  end
end
