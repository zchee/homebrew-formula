require "language/node"

class YamlLanguageServerHead < Formula
  desc "Language Server for Yaml Files"
  homepage "https://github.com/redhat-developer/yaml-language-server"
  license "MIT"
  head "https://github.com/redhat-developer/yaml-language-server.git", branch: "main"

  depends_on "node"
  depends_on "yarn"

  def install
    system "yarn", "install"
    system "yarn", "compile"
    system "yarn", "build:libs"
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
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

    Open3.popen3("#{bin}/yaml-language-server", "--stdio") do |stdin, stdout|
      stdin.write "Content-Length: #{json.size}\r\n\r\n#{json}"
      sleep 3
      assert_match(/^Content-Length: \d+/i, stdout.readline)
    end
  end
end
