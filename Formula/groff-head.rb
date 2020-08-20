class GroffHead < Formula
  desc "GNU troff text-formatting system"
  homepage "https://www.gnu.org/software/groff/"
  head "https://git.savannah.gnu.org/git/groff.git"

  depends_on "autoconf" if build
  depends_on "automake" if build
  depends_on "gawk" if build
  depends_on "ghostscript" if build
  depends_on "libtool" if build
  depends_on "netpbm" if build
  depends_on "texinfo" if build

  def install
    ENV.prepend_path "PATH", Formula["autoconf"].bin
    ENV.prepend_path "PATH", Formula["automake"].bin
    ENV.prepend_path "PATH", Formula["libtool"].bin
    ENV.prepend_path "PATH", Formula["texinfo"].bin
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
