class Doxygen < Formula
  desc "Generate documentation for several programming languages"
  homepage "http://www.doxygen.org/"
  url "https://doxygen.nl/files/doxygen-1.8.18.src.tar.gz"
  mirror "https://downloads.sourceforge.net/project/doxygen/rel-1.8.18/doxygen-1.8.18.src.tar.gz"
  sha256 "18173d9edc46d2d116c1f92a95d683ec76b6b4b45b817ac4f245bb1073d00656"
  head "https://github.com/doxygen/doxygen.git"

  option "with-graphviz", "Build with dot command support from Graphviz."
  option "with-qt", "Build GUI frontend with Qt support."
  option "with-llvm", "Build with libclang support."

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "graphviz" => :optional
  depends_on "llvm" => :optional
  depends_on "ncursse-head" => :optional
  depends_on "pcre" => :optional
  depends_on "qt" => :optional

  def install
    args = std_cmake_args << "-DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=#{MacOS.version}"
    args << "-Dbuild_wizard=ON" if build.with? "qt"
    args << "-Duse_libclang=ON -DLLVM_CONFIG=#{Formula["llvm"].opt_bin}/llvm-config" if build.with? "llvm"
    args << "-DCMAKE_EXE_LINKER_FLAGS_RELEASE='-Wl,-rpath,#{Formula["llvm"].opt_lib} -Wl,-search_paths_first -ltinfow'"

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
    end
    bin.install Dir["build/bin/*"]
    man1.install Dir["doc/*.1"]
  end

  test do
    system "#{bin}/doxygen", "-g"
    system "#{bin}/doxygen", "Doxyfile"
  end
end
