class UgrepHead < Formula
  desc "Ultra fast grep with query UI, fuzzy search, archive search, and more"
  homepage "https://github.com/Genivia/ugrep"
  license "BSD-3-Clause"
  head "https://github.com/Genivia/ugrep.git", branch: "master"

  depends_on "pcre2"
  depends_on "boost"
  depends_on "zlib"
  depends_on "bzip2"
  depends_on "lz4"
  depends_on "zstd"
  depends_on "brotli"
  depends_on "bzip3"
  depends_on "xz"

  def install
    args = %W[
      --enable-color
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-boost-regex
      --with-brotli
      --with-bzip3=#{Formula["bzip3"].opt_prefix}
      --with-bzlib
      --with-lz4
      --with-lzma
      --with-pcre2
      --with-zlib
      --with-zstd
    ]
    ENV.append "LDFLAGS", '/usr/local/opt/bzip2/lib/libbz2.a'
    system "./configure", *args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    assert_match "Hello World!", shell_output("#{bin}/ug 'Hello' '#{testpath}'").strip
    assert_match "Hello World!", shell_output("#{bin}/ugrep 'World' '#{testpath}'").strip
  end
end
