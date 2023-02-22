class Sshpass < Formula
  desc "Non-interactive ssh password auth"
  homepage "http://sourceforge.net/projects/sshpass"
  head "https://git.code.sf.net/p/sshpass/code-git.git", branch: "main"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
    ]

    system "./bootstrap" if build.head?
    system "./configure", *args
    system "make", "install"
  end

  test do
    system "sshpass"
  end
end
