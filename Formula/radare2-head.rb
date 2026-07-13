class Radare2Head < Formula
  desc "Reverse engineering framework"
  homepage "https://radare.org"
  license "LGPL-3.0-only"
  head "https://github.com/radareorg/radare2.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "jemalloc" => :build
  depends_on "libssl" => :build
  depends_on "libuv" => :build
  depends_on "libzip" => :build
  depends_on "lz4" => :build
  depends_on "openssl@3" => :build
  depends_on "xxhash" => :build
  depends_on "zlib" => :build
  depends_on "zydis" => :build

  # Required for r2pm (https://github.com/radareorg/radare2-pm/issues/170)
  depends_on "pkgconf"

  def install
    if Hardware::CPU.intel?
      cflags  = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      ldflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    else
      cpu = `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`.chomp
      cflags  = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      ldflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    end
    ENV.append "CFLAGS", *cflags
    ENV.append "LDFLAGS", *ldflags

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --with-sysmagic
      --with-capstone-next
      --with-syslz4
      --with-syszip
      --with-sysxxhash
      --with-ssl
      --with-ssl-crypto
      --with-libuv
      --with-wasm-browser
      --with-bundle-prefix
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
