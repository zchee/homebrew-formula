class GroffHead < Formula
  desc "GNU troff text-formatting system"
  homepage "https://www.gnu.org/software/groff/"
  head "https://git.savannah.gnu.org/git/groff.git"
  license "GPL-3.0-or-later"

  bottle :unneeded

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "gawk" => :build
  depends_on "ghostscript" => :build
  depends_on "netpbm" => :build
  depends_on "psutils" => :build
  depends_on "texinfo" => :build
  depends_on "uchardet" => :build

  uses_from_macos "libiconv"
  uses_from_macos "perl"

  def install
    system "./bootstrap", "--skip-po"
    system "./configure", "--prefix=#{prefix}", "--without-x", "--with-uchardet", "--with-gs=#{Formula["ghostscript"].bin}/gs", "--with-awk=#{Formula["gawk"].bin}/gawk"
    system "make" # Separate steps required
    system "make", "install"
  end

  test do
    assert_match "homebrew\n",
      pipe_output("#{bin}/groff -a", "homebrew\n")
  end
end
