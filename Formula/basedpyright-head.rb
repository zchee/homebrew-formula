class BasedpyrightHead < Formula
  desc "Pyright fork with various improvements and built-in pylance features"
  homepage "https://github.com/DetachHead/basedpyright"
  license "MIT"
  head "https://github.com/detachhead/basedpyright.git", branch: "main"

  depends_on "node"
  depends_on "uv"

  def install
    system "uv", "sync", "--verbose", "--no-default-groups"
    system "npm", "install"

    cd "packages/pyright" do
      system "npm", "run", "build"
      system "npm", "install", *std_npm_args
    end
    bin.install_symlink libexec/"bin/pyright" => "basedpyright"
    bin.install_symlink libexec/"bin/pyright-langserver" => "basedpyright-langserver"
  end

  test do
    (testpath/"broken.py").write <<~PYTHON
      def wrong_types(a: int, b: int) -> str:
          return a + b
    PYTHON
    output = shell_output("#{bin}/basedpyright broken.py 2>&1", 1)
    assert_match "error: Type \"int\" is not assignable to return type \"str\"", output
  end
end
