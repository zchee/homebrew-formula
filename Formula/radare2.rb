class Radare2 < Formula
  desc "Reverse engineering framework"
  homepage "https://radare.org"
  license "LGPL-3.0-only"
  head "https://github.com/radareorg/radare2.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle :unused

  def install
    ENV.append "CFLAGS", "-march=native -Ofast -flto -arch x86_64"
    ENV.append "CXXFLAGS", "-march=native -Ofast -flto -arch x86_64"

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --with-capstone5
      --with-openssl
      --with-rpath
    ]

    system "./configure", *args
    system "make", "-j", ENV.make_jobs
    system "make", "install"
  end

  test do
    assert_match "radare2 #{version}", shell_output("#{bin}/r2 -v")
  end
end
