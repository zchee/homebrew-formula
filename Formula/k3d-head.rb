class K3dHead < Formula
  desc "Little helper to run Rancher Lab's k3s in Docker"
  homepage "https://k3d.io"
  head "https://github.com/rancher/k3d.git", branch: "main"
  license "MIT"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "go" => :build

  def install
    require "net/http"
    uri = URI("https://update.k3s.io/v1-release/channels")
    resp = Net::HTTP.get(uri)
    resp_json = JSON.parse(resp)
    k3s_version = resp_json["data"].find { |channel| channel["id"]=="stable" }["latest"].sub("+", "-")
    revision = Utils.git_short_head

    ldflags = %W[
      -s -w
      -X github.com/rancher/k3d/v#{version.major}/version.Version=v#{revision}
      -X github.com/rancher/k3d/v#{version.major}/version.K3sVersion=#{k3s_version}
    ]

    system "go", "build", "-mod", "vendor", "-trimpath", "-o=#{prefix}/bin/k3d", "-ldflags=#{ldflags.join(" ")}"

    # Install bash completion
    output = Utils.safe_popen_read(bin/"k3d", "completion", "bash")
    (bash_completion/"k3d").write output

    # Install zsh completion
    output = Utils.safe_popen_read(bin/"k3d", "completion", "zsh")
    (zsh_completion/"_k3d").write output

    # Install fish completion
    output = Utils.safe_popen_read(bin/"k3d", "completion", "fish")
    (fish_completion/"k3d.fish").write output
  end

  test do
    assert_match "k3d version v#{version}", shell_output("#{bin}/k3d version")
    # Either docker is not present or it is, where the command will fail in the first case.
    # In any case I wouldn't expect a cluster with name 6d6de430dbd8080d690758a4b5d57c86 to be present
    # (which is the md5sum of 'homebrew-failing-test')
    output = shell_output("#{bin}/k3d cluster get 6d6de430dbd8080d690758a4b5d57c86 2>&1", 1).split("\n").pop
    assert_match "No nodes found for given cluster", output
  end
end
