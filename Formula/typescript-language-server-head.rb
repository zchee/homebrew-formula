require "language/node"

class TypescriptLanguageServerHead < Formula
  desc "Language Server Protocol implementation for TypeScript wrapping tsserver"
  homepage "https://github.com/typescript-language-server/typescript-language-server"
  license all_of: ["MIT", "Apache-2.0"]
  head "https://github.com/typescript-language-server/typescript-language-server.git", branch: "master"

  depends_on "corepack"
  depends_on "node"

  def install
    system "#{Formula["corepack"].bin}/yarn", "add", "typescript@next"
    system "#{Formula["corepack"].bin}/yarn"
    system "#{Formula["corepack"].bin}/yarn", "run", "build"
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)

    node_modules = libexec/"lib/node_modules"
    node_modules.install "node_modules/typescript"

    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    require "open3"

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

    Open3.popen3("#{bin}/typescript-language-server", "--stdio") do |stdin, stdout|
      stdin.write "Content-Length: #{json.size}\r\n\r\n#{json}"
      assert_match(/^Content-Length: \d+/i, stdout.readline)
    end
  end
end
