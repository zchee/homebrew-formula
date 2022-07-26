class KoHead < Formula
  desc "Build and deploy Go applications on Kubernetes"
  homepage "https://github.com/google/ko"
  head "https://github.com/google/ko.git", branch: "main"
  license "Apache-2.0"

  depends_on "go" => :build

  def install
    system "go", "build", "-trimpath", "-o=#{bin}/ko", "-ldflags=-s -w -X github.com/google/ko/pkg/commands.Version=#{version}"

    bash_output = Utils.safe_popen_read(bin/"ko", "completion", "bash")
    (bash_completion/"ko").write bash_output

    zsh_output = Utils.safe_popen_read(bin/"ko", "completion", "zsh")
    (zsh_completion/"_ko").write zsh_output

    fish_output = Utils.safe_popen_read(bin/"ko", "completion", "fish")
    (fish_completion/"ko.fish").write fish_output
  end

  test do
    output = shell_output("#{bin}/ko login reg.example.com -u brew -p test 2>&1")
    assert_match "logged in via #{testpath}/.docker/config.json", output
  end
end
