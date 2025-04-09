class PyrightHead < Formula
  desc "Static type checker for Python"
  homepage "https://github.com/microsoft/pyright"
  license "MIT"
  head "https://github.com/microsoft/pyright.git", branch: "main"

  depends_on "node"

  def install
    system "npm", "install"
    cd "packages/pyright" do
      system "npm", "run", "build"
      system "npm", "install", *std_npm_args
    end
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    (testpath/"broken.py").write <<~PYTHON
      def wrong_types(a: int, b: int) -> str:
          return a + b
    PYTHON
    output = pipe_output("#{bin}/pyright broken.py 2>&1")
    assert_match "error: Type \"int\" is not assignable to return type \"str\"", output
  end
end
