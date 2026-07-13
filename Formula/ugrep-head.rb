class UgrepHead < Formula
  desc "Ultra fast grep with query UI, fuzzy search, archive search, and more"
  homepage "https://github.com/Genivia/ugrep"
  license "BSD-3-Clause"
  head "https://github.com/Genivia/ugrep.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "boost" => :build
  depends_on "brotli" => :build
  depends_on "bzip2" => :build
  depends_on "bzip3" => :build
  depends_on "lz4" => :build
  depends_on "pcre2" => :build
  depends_on "xz" => :build
  depends_on "zlib" => :build
  depends_on "zstd" => :build
  depends_on "libtool" => :head

  def install
    system "autoreconf", "-fiv"

    # hard coded to `Static::cores` is 4 when [__APPLE__ && HAVE_NEON]. `Static::cores = std::thread::hardware_concurrency();` instead of.
    inreplace "src/ugrep.cpp", /(#if defined\(__APPLE__\)) && (defined\(HAVE_NEON\))/, "\\1 && !\\2"
    system "cat", "src/ugrep.cpp"

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-boost-regex=#{formula_opt_prefix("boost")}
      --with-brotli=#{formula_opt_prefix("brotli")}
      --with-bzlib=#{formula_opt_prefix("bzip2")}
      --with-bzip3=#{formula_opt_prefix("bzip3")}
      --with-lz4=#{formula_opt_prefix("lz4")}
      --with-pcre2=#{formula_opt_prefix("pcre2")}
      --with-lzma=#{formula_opt_prefix("xz")}
      --with-zlib=#{formula_opt_prefix("zlib")}
      --with-zstd=#{formula_opt_prefix("zstd")}
      --with-bash-completion-dir
      --with-fish-completion-dir
      --with-zsh-completion-dir
    ]

    if Hardware::CPU.intel?
      cflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      cxxflags  = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c++20"
      ldflags = "-march=x86-64-v4 -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    else
      cpu = `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`.chomp
      cflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c2x"
      cxxflags  = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto -std=c++20"
      ldflags = "-mcpu=#{cpu} -O3 -funroll-loops -ffast-math -fforce-addr -flto"
    end
    libs = %W[
      #{formula_opt_lib("bzip2")}/libbz2.a
      #{formula_opt_lib("bzip3")}/libbzip3.a
      #{formula_opt_lib("lz4")}/liblz4.a
      #{formula_opt_lib("pcre2")}/libpcre2-8.a
      #{formula_opt_lib("xz")}/liblzma.a
      #{formula_opt_lib("zlib")}/libz.a
      #{formula_opt_lib("zstd")}/libzstd.a
    ]

    ENV.append "CFLAGS", *cflags
    ENV.append "CXXFLAGS", *cxxflags
    ENV.append "LDFLAGS", *ldflags
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
