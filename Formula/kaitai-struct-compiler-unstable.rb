class KaitaiStructCompilerUnstable < Formula
  desc "Compiler for generating binary data parsers"
  homepage "https://kaitai.io/"
  version "0.9-SNAPSHOT20191110.035947.dca5f276"
  url "https://bintray.com/kaitai-io/universal_unstable/download_file?file_path=kaitai-struct-compiler-#{version}.zip"

  depends_on :java => "1.8+"

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/kaitai-struct-compiler"
  end

  test do
    (testpath/"Test.ksy").write <<~EOS
      meta:
        id: test
        endian: le
        file-extension: test
      seq:
        - id: header
          type: u4
    EOS
    system bin/"kaitai-struct-compiler", "Test.ksy", "-t", "java", "--outdir", testpath
    assert_predicate testpath/"src/Test.java", :exist?
  end
end
