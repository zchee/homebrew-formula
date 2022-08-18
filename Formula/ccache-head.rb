class CcacheHead < Formula
  desc "Object-file caching compiler wrapper"
  homepage "https://ccache.dev/"
  head "https://github.com/ccache/ccache.git", branch: "master"

  uses_from_macos "zlib"

  depends_on "asciidoc" => :build
  depends_on "cmake" => :build
  depends_on "git-head" => :build
  depends_on "hiredis" => :build
  depends_on "libtool" => :build
  depends_on "zstd" => :build

  def install
    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog" if build.head?

    args = std_cmake_args
    args << "-DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=#{MacOS.version}"
    args << "-DCMAKE_VERBOSE_MAKEFILE:BOOL=TRUE"
    args << "-DCMAKE_C_STANDARD=11"
    args << "-DCMAKE_CXX_STANDARD=11"
    args << "-DENABLE_TESTING:BOOL=OFF"
    args << "-DA2X_EXE:FILEPATH=#{Formula["asciidoc"].opt_bin}/a2x"
    args << "-DASCIIDOC_EXE:FILEPATH=#{Formula["asciidoc"].opt_bin}/asciidoc"
    args << "-DGIT_EXECUTABLE:FILEPATH=#{Formula["git"].opt_bin}/git"
    args << "-DZSTD_INCLUDE_DIR:PATH=#{Formula["zstd"].opt_include}"
    args << "-DZSTD_LIBRARY:FILEPATH=#{Formula["zstd"].opt_lib}/libzstd.dylib"

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
      system "make", "doc-man-page"
      system "make", "install"
      man1.install "doc/Ccache.1"
    end

    libexec.mkpath
    %w[
      clang
      clang++
      cc
      gcc gcc2 gcc3 gcc-3.3 gcc-4.0 gcc-4.2 gcc-4.3 gcc-4.4 gcc-4.5 gcc-4.6 gcc-4.7 gcc-4.8 gcc-4.9 gcc-5 gcc-6 gcc-7 gcc-8 gcc-9
      c++ c++3 c++-3.3 c++-4.0 c++-4.2 c++-4.3 c++-4.4 c++-4.5 c++-4.6 c++-4.7 c++-4.8 c++-4.9 c++-5 c++-6 c++-7 c++-8 c++-9
      g++ g++2 g++3 g++-3.3 g++-4.0 g++-4.2 g++-4.3 g++-4.4 g++-4.5 g++-4.6 g++-4.7 g++-4.8 g++-4.9 g++-5 g++-6 g++-7 g++-8 g++-9
    ].each do |prog|
      libexec.install_symlink bin/"ccache" => prog
    end

  end

  def caveats; <<~EOS
    To install symlinks for compilers that will automatically use
    ccache, prepend this directory to your PATH:
      #{opt_libexec}

    If this is an upgrade and you have previously added the symlinks to
    your PATH, you may need to modify it to the path specified above so
    it points to the current version.

    NOTE: ccache can prevent some software from compiling.
    ALSO NOTE: The brew command, by design, will never use ccache.
  EOS
  end

  test do
    ENV.prepend_path "PATH", opt_libexec
    assert_equal "#{opt_libexec}/gcc", shell_output("which gcc").chomp
    system "#{bin}/ccache", "-s"
  end
end
