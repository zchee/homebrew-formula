class Tccutil < Formula
  desc "Utility to modify the macOS Accessibility Database (TCC.db)"
  homepage "https://github.com/jacobsalmela/tccutil"
  license "GPL-2.0-or-later"
  head "https://github.com/jacobsalmela/tccutil.git", branch: "master"

  def install
    bin.install "tccutil.py" => "tccutil.py"
  end

  test do
    system "#{bin}/tccutil", "--help"
  end
end
