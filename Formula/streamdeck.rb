require "language/node"

class Streamdeck < Formula
  desc "CLI tool for building with Stream Deck"
  homepage "https://github.com/elgatosf/cli"
  head "https://github.com/elgatosf/cli.git", branch: "main"

  depends_on "node"

  def install
    system "npm", "install", *Language::Node.local_npm_install_args
    system "npm", "run", "build"

    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end
end
