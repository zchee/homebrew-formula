class Notary < Formula
  desc "Trust over arbitrary collections of data"
  homepage "https://github.com/notaryproject/notary"
  head "https://github.com/notaryproject/notary.git", branch: "master"
  license "Apache-2.0"

  depends_on "go" => :build

  def install
    system "go", "build", "-o", bin/"notary", "-tags=pkcs11", "-trimpath", "./cmd/notary"
  end
end
