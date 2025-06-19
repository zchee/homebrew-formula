class KubectlAiHead < Formula
  desc "AI powered Kubernetes Assistant"
  homepage "https://github.com/GoogleCloudPlatform/kubectl-ai"
  license "Apache-2.0"

  head "https://github.com/GoogleCloudPlatform/kubectl-ai.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ldflags = "-s -w -X main.version=#{version} -X main.commit=#{Utils.git_head} -X main.date=#{time.iso8601}"
    system "go", "build", *std_go_args(output: bin/"kubectl-ai", ldflags:), "./cmd"

    generate_completions_from_executable(bin/"kubectl-ai", "completion", shells: [:bash, :zsh, :fish, :pwsh], base_name: "kubectl-ai")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/kubectl-ai version")

    ENV["GEMINI_API_KEY"] = "test"
    PTY.spawn(bin/"kubectl-ai", "--llm-provider", "gemini") do |r, w, pid|
      sleep 1
      w.puts "test"
      sleep 1
      output = r.read_nonblock(1024)
      assert_match "Hey there, what can I help you with", output
    rescue Errno::EIO
      # End of input, ignore
    ensure
      Process.kill("TERM", pid)
    end
  end
end
