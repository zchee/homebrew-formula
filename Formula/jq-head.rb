class JqHead < Formula
  desc "Lightweight and flexible command-line JSON processor"
  homepage "https://stedolan.github.io/jq/"
  head "https://github.com/stedolan/jq.git"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "oniguruma" => :build
  depends_on "pipenv" => :build
  depends_on "python" => :build

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --disable-maintainer-mode
      --disable-docs
      --prefix=#{prefix}
      --with-oniguruma=#{Formula["oniguruma"].opt_prefix}
    ]

    system "autoreconf", "-iv" if build.head?
    system "./configure", *args
    system "make", "install"
  end

  test do
    assert_equal "2\n", pipe_output("#{bin}/jq .bar", '{"foo":1, "bar":2}')
  end
end
