class SopsHead < Formula
  desc "Editor of encrypted files"
  homepage "https://github.com/mozilla/sops"
  license "MPL-2.0"
  head "https://github.com/mozilla/sops.git", branch: "develop"

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
      -linkmode=external
      -buildmode=pie
      -buildid=
      "-extldflags=-static-pie -all_load -dead_strip -Wl,-no_deduplicate"
    ].join(" ")

    tags = %W[
      osusergo
      netgo
      static
    ].join(",")

    ENV["CGO_ENABLED"] = "0"
    system "go", "build", *std_go_args(ldflags: ldflags), "-tags=#{tags}", "-o", bin/"sops", "go.mozilla.org/sops/v3/cmd/sops"
    pkgshare.install "example.yaml"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/sops --version")

    assert_match "Recovery failed because no master key was able to decrypt the file.",
      shell_output("#{bin}/sops #{pkgshare}/example.yaml 2>&1", 128)
  end
end
