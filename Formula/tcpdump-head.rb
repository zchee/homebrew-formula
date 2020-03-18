class TcpdumpHead < Formula
  desc "Command-line packet analyzer"
  homepage "https://www.tcpdump.org/"
  head "https://github.com/the-tcpdump-group/tcpdump.git"

  depends_on "libpcap"
  depends_on "libressl"

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--enable-ipv6",
                          "--disable-smb",
                          "--disable-universal",
                          "--with-cap-ng",
                          "--with-system-libpcap",
                          "--without-gcc"
                          "--with-crypto=#{Formula["libressl"].opt_prefix}"
    system "make", "install"
  end

  test do
    system sbin/"tcpdump", "--help"
  end
end
