class GroffHead < Formula
  desc "GNU troff text-formatting system"
  homepage "https://www.gnu.org/software/groff/"
  head "https://git.savannah.gnu.org/git/groff.git"

  depends_on "autoconf" if build.head?
  depends_on "automake" if build.head?
  depends_on "gawk" if build.head?
  depends_on "ghostscript" if build.head?
  depends_on "libtool" if build.head?
  depends_on "netpbm" if build.head?

  def install
    ENV.prepend_path "PATH", Formula["netpbm"].bin

    system "./bootstrap", "--skip-po"
    system "./configure", "--prefix=#{prefix}", "--without-x", "--with-gs=#{Formula["ghostscript"].bin}/gs", "--with-awk=#{Formula["gawk"].bin}/gawk"
    system "make" # Separate steps required
    system "make", "install"
  end

  test do
    assert_match "homebrew\n",
      pipe_output("#{bin}/groff -a", "homebrew\n")
  end
end
