class ContainerUse < Formula
  desc "Development environments for coding agents. Enable multiple agents to work safely and independently with your preferred stack."
  homepage "https://container-use.com/"
  license "Apache-2.0"

  head "https://github.com/dagger/container-use.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ldflags = "-s -w -X main.version=#{version} -X main.commit=#{Utils.git_head} -X main.date=#{time.iso8601}"
    system "go", "build", *std_go_args(output: bin/"container-use", ldflags:), "./cmd/container-use"
    bin.install_symlink "container-use" => "cu"

    generate_completions_from_executable(bin/"container-use", "completion", shells: [:bash, :zsh, :fish], base_name: "container-use")
    generate_completions_from_executable(bin/"container-use", "completion", "--command-name=cu", shells: [:bash, :zsh, :fish], base_name: "cu")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/container-use version")

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
