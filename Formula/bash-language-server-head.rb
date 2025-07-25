class BashLanguageServerHead < Formula
  desc "Language Server for Bash"
  homepage "https://github.com/bash-lsp/bash-language-server"
  license "MIT"
  head "https://github.com/bash-lsp/bash-language-server.git", branch: "main"

  depends_on "node"
  depends_on "pnpm"

  def install
    system "pnpm", "install"
    system "pnpm", "compile"
    cd "server" do
      system "npm", "install", *std_npm_args
    end
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    json = <<~JSON
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
          "rootUri": null,
          "capabilities": {}
        }
      }
    JSON
    input = "Content-Length: #{json.size}\r\n\r\n#{json}"
    output = pipe_output("#{bin}/bash-language-server start", input, 0)
    assert_match(/^Content-Length: \d+/i, output)
  end
end
