class ChainsawHead < Formula
  desc "Declarative K8s e2e testing"
  homepage "https://kyverno.github.io/chainsaw/"
  head "https://github.com/kyverno/chainsaw.git", branch: "main"
  license "Apache-2.0"

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = %W[
      -s -w
    ]
    system "go", "build", *std_go_args(output: bin/"chainsaw", ldflags: ldflags)

    generate_completions_from_executable(bin/"chainsaw", "completion", base_name: "chainsaw")
  end
end
