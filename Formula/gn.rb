class Gn < Formula
  desc "GN is a meta-build system that generates build files for Ninja."
  homepage "https://gn.googlesource.com/gn"
  head "https://gn.googlesource.com/gn.git"

  depends_on "ninja" => :build
  depends_on "python" => :build

  def install
    system "#{Formula["python"].bin}/python3", "build/gen.py",
      "--platform=darwin", "--use-lto", "--use-icf"
    system "#{Formula["ninja"].opt_prefix}/bin/ninja", "-C", "out", "gn"

    bin.install "out/gn" => "gn"
    lib.install "out/gn_lib.a" => "gn_lib.a"
  end
end
