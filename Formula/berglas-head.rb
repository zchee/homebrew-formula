class BerglasHead < Formula
  desc "Tool for managing secrets on Google Cloud"
  homepage "https://github.com/GoogleCloudPlatform/berglas"
  head "https://github.com/GoogleCloudPlatform/berglas.git"

  depends_on "go"

  def install
    system "go", "build", "-a", "-ldflags='-s -w \"-extldflags=-fno-PIC -static\"'", "-installsuffix=cgo", "-tags=netgo", "-mod=vendor", "-o", bin/"berglas"
  end

  test do
    assert_match "#{version}\n", shell_output("#{bin}/berglas --version 2>&1")
    out = shell_output("#{bin}/berglas list homebrewtest 2>&1", 61)
    assert_match "could not find default credentials.", out
  end
end
