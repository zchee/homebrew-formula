class Less < Formula
  desc "Pager program similar to more"
  homepage "http://www.greenwoodsoftware.com/less/index.html"
  url "http://www.greenwoodsoftware.com/less/less-551.tar.gz"
  sha256 "ff165275859381a63f19135a8f1f6c5a194d53ec3187f94121ecd8ef0795fe3d"

  depends_on "pcre2"

  def install
    system "./configure", "--prefix=#{prefix}", "--with-regex=pcre2", "--with-editor=nvim"
    system "make", "install"
  end

  test do
    system "#{bin}/lesskey", "-V"
  end
end
