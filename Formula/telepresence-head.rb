class TelepresenceHead < Formula
  desc "Local dev environment attached to a remote Kubernetes cluster"
  homepage "https://telepresence.io"
  head "https://github.com/telepresenceio/telepresence.git", branch: "release/v2"

  depends_on "go" => :build
  depends_on "jq" => :build

  def install
    system "make", "build"
    bin.install "build-output/bin/telepresence"
    bin.install "build-output/fuseftp-darwin-amd64" => "fuseftp"

    generate_completions_from_executable(bin/"telepresence", "completion", base_name: "telepresence")
  end

  test do
    system "#{bin}/telepresence", "--help"
  end
end
