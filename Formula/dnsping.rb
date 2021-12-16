class Dnsping < Formula
  desc "Like ping but for DNS servers: checks latency and errors and report statistics"
  homepage "https://fortio.org/dnsping/"
  head "https://github.com/fortio/dnsping.git", branch: "main"
  license "Apache-2.0"

  depends_on "go" => :build

  def install
    system "make", "official-build", "OFFICIAL_BIN=#{bin}/dnsping"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dnsping version")
    output = shell_output("#{bin}/dnsping -c 1 www.google.com 8.8.8.8")
    assert_match(/^# target/, output.lines.last)
  end
end
