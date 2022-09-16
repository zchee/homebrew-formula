class DoxygenLlvm < Formula
  desc "Generate documentation for several programming languages"
  homepage "https://www.doxygen.nl/"
  url "https://doxygen.nl/files/doxygen-1.9.5.src.tar.gz"
  mirror "https://downloads.sourceforge.net/project/doxygen/rel-1.9.5/doxygen-1.9.5.src.tar.gz"
  sha256 "55b454b35d998229a96f3d5485d57a0a517ce2b78d025efb79d57b5a2e4b2eec"
  license "GPL-2.0-only"
  head "https://github.com/doxygen/doxygen.git", branch: "master"

  livecheck do
    url "https://www.doxygen.nl/download.html"
    regex(/href=.*?doxygen[._-]v?(\d+(?:\.\d+)+)[._-]src\.t/i)
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "python@3.10" => :build # Fails to build with macOS Python3
  uses_from_macos "flex" => :build, since: :big_sur

  depends_on "graphviz" => :build
  depends_on "llvm" => :build
  depends_on "ncurses-head" => :build
  depends_on "pcre" => :build
  depends_on "sqlite3" => :build

  # Need gcc>=7.2. See https://gcc.gnu.org/bugzilla/show_bug.cgi?id=66297
  fails_with gcc: "5"
  fails_with gcc: "6"

  def install
    args = %W[
      -Dbuild_parse:BOOL=ON
      -Duse_libclang:BOOL=ON
      -Duse_sqlite3:BOOL=ON
      -DCMAKE_PREFIX_PATH=/usr/local/opt/llvm /usr/local/opt/sqlite /usr/local/opt/ncurses-head /usr/local/opt/pcre
    ]
    system "cmake", "-S", ".", "-B", "build", *(std_cmake_args + args)
    system("cmake -C . -LA 2>/dev/null | awk '{if(NR>2)print}' || true")
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    system "cmake", "-S", ".", "-B", "build", "-Dbuild_doc=1", *(std_cmake_args + args)
    man1.install buildpath.glob("build/man/*.1")
  end

  test do
    system bin/"doxygen", "-g"
    system bin/"doxygen", "Doxyfile"
  end
end
