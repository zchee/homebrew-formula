class UgrepIndexer < Formula
  desc "A monotonic indexer to speed up grepping by >10x"
  homepage "https://github.com/Genivia/ugrep"
  license "BSD-3-Clause"

  option("without-avx512", "Enable AVX512 feature")

  head do
    url "https://github.com/Genivia/ugrep-indexer.git", :branch => "main"

    depends_on "pkg-config"
    depends_on "autoconf"
    depends_on "automake"
    depends_on "libtool"

    depends_on "brotli"
    depends_on "bzip2"
    depends_on "bzip3"
    depends_on "lz4"
    depends_on "xz"
    depends_on "zlib"
    depends_on "zstd"
  end

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --with-zlib
      --with-bzlib
      --with-lzma
      --with-lz4
      --with-zstd
      --with-brotli
      --with-bzip3
    ]

    c_flags = Hardware::CPU.intel? ? %W[-march=x86-64-v4] : %W[-march=apple-latest]
    cxx_flags = Hardware::CPU.intel? ? %W[-march=x86-64-v4] : %W[-march=apple-latest]
    c_flags.append ["-Ofast -flto -std=c17"]
    cxx_flags.append ["-Ofast -flto -std=c++17 -stdlib=libc++"]

    c_flags.append ["-mavx -mavx2 -mavx512f -mavx512cd -mavx512dq -mavx512bw -mavx512vl -mavx512vnni"] if not :with_avx512?
    cxx_flags.append ["-mavx -mavx2 -mavx512f -mavx512cd -mavx512dq -mavx512bw -mavx512vl -mavx512vnni"] if not :with_avx512?

    ldflags = %W[/usr/local/opt/zlib/lib/libz.a /usr/local/opt/bzip2/lib/libbz2.a /usr/local/opt/xz/lib/liblzma.a /usr/local/opt/lz4/lib/liblz4.a /usr/local/opt/zstd/lib/libzstd.a -L/usr/local/opt/brotli/lib /usr/local/opt/bzip3/lib/libbzip3.a]

    system "autoreconf", "-fiv"
    system "./configure", *args, "CFLAGS=#{c_flags.join(" ")}", "CXXFLAGS=#{cxx_flags.join(" ")}", "LDFLAGS=#{ldflags.join(" ")}"
    inreplace ["Makefile", "Src/Makefile"],
      "LIBS = -lviiz -lbzip3 -lbrotlidec -lbrotlienc -lzstd -llz4 -llzma -lbz2 -lz",
      "LIBS = -lviiz -lbrotlidec -lbrotlienc"

    system "make", "install"
  end
end
