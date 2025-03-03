class SopsHead < Formula
  desc "Editor of encrypted files"
  homepage "https://github.com/getsops/sops"
  license "MPL-2.0"
  head "https://github.com/getsops/sops.git", branch: "main"

  depends_on "go" => :build

  def install
    system "go", "mod", "tidy"
    system "go", "build", *std_go_args, "-o", bin/"sops", "./cmd/sops"
    pkgshare.install "example.yaml"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/sops --version")

    assert_match "Recovery failed because no master key was able to decrypt the file.",
      shell_output("#{bin}/sops #{pkgshare}/example.yaml 2>&1", 128)
  end
end
