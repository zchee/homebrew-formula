class BashdbHead < Formula
  desc "Bash shell debugger"
  homepage "https://bashdb.sourceforge.io"
  license "GPL-2.0"
  head "https://git.code.sf.net/p/bashdb/code.git", :branch => "bash-5.0"

  # We check the "bashdb" directory page because the bashdb project contains
  # various software and bashdb releases may be pushed out of the SourceForge
  # RSS feed.
  livecheck do
    url "https://sourceforge.net/projects/bashdb/files/bashdb/"
    strategy :page_match
    regex(%r{href=(?:["']|.*?bashdb/)?v?(\d+(?:[.-]\d+)+)/?["' >]}i)
  end

  bottle :unneeded

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "bash" => :build

  def install
    system "sh", "autogen.sh"
    system "./configure", "--with-bash=#{Formula["bash"].bin}/bash",
                          "--disable-debug",
                          "--disable-dependency-tracking",
                          "--prefix=#{prefix}"

    system "make", "install"
  end

  test do
    assert_match version.to_s, pipe_output("#{bin}/bashdb --version 2>&1")
  end
end
