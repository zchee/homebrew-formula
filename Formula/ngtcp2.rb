class Ngtcp2 < Formula
  desc "ngtcp2 project is an effort to implement IETF QUIC protocol"
  homepage "https://github.com/ngtcp2/ngtcp2"

  head do
    url "https://github.com/ngtcp2/ngtcp2.git"

    depends_on "cmake"
  end

  depends_on "pkg-config" => :build
  depends_on "openssl-quic"

  def install
    args = std_cmake_args << "-Wno-dev"
    args << "-DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=#{MacOS.version}"
    args << "-DCMAKE_C_STANDARD=11"
    args << "-DCMAKE_CXX_STANDARD=17"
    args << "-DENABLE_GNUTLS:BOOL=OFF"
    args << "-DENABLE_OPENSSL:BOOL=ON"
    args << "-DOPENSSL_INCLUDE_DIRS:PATH=#{Formula["openssl-quic"].opt_include}"
    args << "-DOPENSSL_LIBRARIES:PATH=#{Formula["openssl-quic"].opt_lib}"
    args << "-DLIBEV_INCLUDE_DIR:PATH="
    args << "-DLIBEV_LIBRARY:FILEPATH="
    args << "-DLIBNGHTTP3_INCLUDE_DIR:PATH="
    args << "-DLIBNGHTTP3_LIBRARY:FILEPATH="

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
      system "make", "check"
      system "make", "install"
    end
  end
end
