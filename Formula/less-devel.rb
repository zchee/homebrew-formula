class LessDevel < Formula
  desc "Pager program similar to more"
  homepage "http://www.greenwoodsoftware.com/less/index.html"
  url "http://www.greenwoodsoftware.com/less/less-562.tar.gz"
  sha256 "eab470c7c928132441541aa49b1352c0fc699c30f762dfaeb3bf88e6f0fd701b"

  livecheck do
    url :homepage
    regex(/less[._-]v?(\d+).+?released.+?general use/i)
  end

  bottle :unneeded

  depends_on "pcre"
  depends_on "ncurses-head"

  def install
    system "./configure", "--prefix=#{prefix}", "--with-regex=pcre"
    system "make", "install"
  end

  test do
    system "#{bin}/lesskey", "-V"
  end
end
