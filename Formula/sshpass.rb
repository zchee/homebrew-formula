class Sshpass < Formula
  desc "Non-interactive ssh password auth"
  homepage "http://sourceforge.net/projects/sshpass"
  url "https://downloads.sourceforge.net/project/sshpass/sshpass/1.06/sshpass-1.06.tar.gz"
  version "1.06"
  sha256 "c6324fcee608b99a58f9870157dfa754837f8c48be3df0f5e2f3accf145dee60"
  head "https://svn.code.sf.net/p/sshpass/code/trunk"

  depends_on "autoconf" => :head
  depends_on "automake" => :head
  depends_on "libtool" => :head

  def install
    system "./bootstrap" if build.head?
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    system "sshpass"
  end
end
