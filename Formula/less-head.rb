class LessHead < Formula
  desc "Pager program similar to more"
  homepage "http://www.greenwoodsoftware.com/less/index.html"
  url "http://www.greenwoodsoftware.com/less/less-557.tar.gz"
  sha256 "510e1fe87de3579f7deb4bec38e6d0ad959663d54598729c4cc43a4d64d5b1f7"

  depends_on "pcre2"
  depends_on "ncurses-head"

  def install
    system "./configure", "--prefix=#{prefix}", "--with-regex=pcre2"
    system "make", "install"
  end

  test do
    system "#{bin}/lesskey", "-V"
  end
end
