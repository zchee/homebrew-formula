class Aria2Head < Formula
  desc "Download with resuming and segmented downloading"
  homepage "https://aria2.github.io/"
  license "GPL-2.0-or-later"

  head do
    url "https://github.com/aria2/aria2.git", :branch => "master"

    depends_on "autoconf"
    depends_on "automake"
    depends_on "libtool"
  end

  depends_on "pkg-config" => :build
  depends_on "gettext" => :build
  depends_on "libssh2" => :build
  depends_on "openssl@3" => :build
  depends_on "sqlite" => :build
  depends_on "libuv" => :build
  depends_on "c-ares" => :build
  depends_on "jemalloc" => :build

  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  def install
    ENV.cxx11

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --with-libssh2
      --with-libuv
      --with-jemalloc
      --without-gnutls
      --without-libgmp
      --without-libnettle
      --without-libgcrypt
    ]
    if OS.mac?
      args << "--with-appletls"
      args << "--without-openssl"
    else
      args << "--without-appletls"
      args << "--with-openssl"
    end

    system "autoreconf", "-i"
    system "./configure", *args
    system "make", "install"

    bash_completion.install "doc/bash_completion/aria2c"
  end

  test do
    system "#{bin}/aria2c", "https://brew.sh/"
    assert_predicate testpath/"index.html", :exist?, "Failed to create index.html!"
  end
end
