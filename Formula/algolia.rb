class Algolia < Formula
  desc "Algolia CLI utility"
  homepage "https://www.algolia.com"
  license "MIT"
  head "https://github.com/algolia/cli.git", :branch => "main"

  depends_on "go" => :build

  def install
    system "go", "generate", "./..."

    revision = Utils.git_short_head
    ldflags = %W[
      -s -w
      -X github.com/algolia/cli/pkg/version.Version=#{revision}
    ]
    system "go", "build", "-ldflags", ldflags.join(" "), *std_go_args, "./cmd/algolia"

    # Install bash completion
    output = Utils.safe_popen_read(bin/"algolia", "completion", "bash")
    (bash_completion/"algolia").write output

    # Install zsh completion
    output = Utils.safe_popen_read(bin/"algolia", "completion", "zsh")
    (zsh_completion/"_algolia").write output

    # Install fish completion
    output = Utils.safe_popen_read(bin/"algolia", "completion", "fish")
    (zsh_completion/"algolia.fish").write output
  end
end
