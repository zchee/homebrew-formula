class UgrepHead < Formula
  desc "Ultra fast grep with query UI, fuzzy search, archive search, and more"
  homepage "https://github.com/Genivia/ugrep"
  license "BSD-3-Clause"
  head "https://github.com/Genivia/ugrep.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :head
  depends_on "boost" => :build
  depends_on "brotli" => :build
  depends_on "bzip2" => :build
  depends_on "bzip3" => :build
  depends_on "lz4" => :build
  depends_on "pcre2" => :build
  depends_on "xz" => :build
  depends_on "zlib" => :build
  depends_on "zstd" => :build

  def install
    system "autoreconf", "-fiv"

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-boost-regex=#{Formula["boost"].opt_prefix}
      --with-brotli=#{Formula["brotli"].opt_prefix}
      --with-bzlib=#{Formula["bzip2"].opt_prefix}
      --with-bzip3=#{Formula["bzip3"].opt_prefix}
      --with-lz4=#{Formula["lz4"].opt_prefix}
      --with-pcre2=#{Formula["pcre2"].opt_prefix}
      --with-lzma=#{Formula["xz"].opt_prefix}
      --with-zlib=#{Formula["zlib"].opt_prefix}
      --with-zstd=#{Formula["zstd"].opt_prefix}
      --with-bash-completion-dir
      --with-fish-completion-dir
      --with-zsh-completion-dir
    ]

    cxxflags = "-march=native -Ofast -flto -std=c++20"
    cxxflags += Hardware::CPU.intel? ? " -mcpu=x86-64-v4" : " -mcpu=apple-latest"
    libs = %W[
      #{Formula["pcre2"].opt_lib}/libpcre2-8.a
      #{Formula["zlib"].opt_lib}/libz.a
      #{Formula["bzip2"].opt_lib}/libbz2.a
      #{Formula["xz"].opt_lib}/liblzma.a
      #{Formula["lz4"].opt_lib}/liblz4.a
      #{Formula["zstd"].opt_lib}/libzstd.a
      #{Formula["bzip3"].opt_lib}/libbzip3.a
    ]

    ENV.append "CXXFLAGS", *cxxflags
    ENV.append "LIBS", libs.join(" ")

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
