class LibeventHead < Formula
  desc "Asynchronous event library"
  homepage "https://libevent.org/"
  license "BSD-3-Clause"
  head "https://github.com/libevent/libevent.git"

  livecheck do
    url :homepage
    regex(/libevent[._-]v?(\d+(?:\.\d+)+)-stable/i)
  end

  keg_only "unstable"

  depends_on "cmake" => :build
  depends_on "openssl@1.1" => :build
  depends_on "pkg-config" => :build

  def install
    args = std_cmake_args
    args << "-DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=#{MacOS.version}"
    args << "-DCMAKE_VERBOSE_MAKEFILE:BOOL=TRUE"
    args << "-DCMAKE_C_STANDARD=11"
    args << "-DCMAKE_CXX_STANDARD=11"
    args << "-DEVENT__DISABLE_MBEDTLS=TRUE"
    args << "-DEVENT__DISABLE_TESTS=TRUE"

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
      system "make", "install"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <event2/event.h>

      int main()
      {
        struct event_base *base;
        base = event_base_new();
        event_base_free(base);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-levent", "-o", "test"
    system "./test"
  end
end
