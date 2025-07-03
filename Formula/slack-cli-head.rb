class SlackCliHead < Formula
  desc "Create, develop, and deploy Slack apps from the command-line"
  homepage "https://github.com/slackapi/slack-cli"
  license "Apache-2.0"

  head "https://github.com/slackapi/slack-cli.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    ldflags_version = Utils.safe_popen_read("git describe --abbrev=0 --tags").chomp
    ldflags = "-s -w -X github.com/slackapi/slack-cli/internal/pkg/version.Version=#{ldflags_version}"
    system "go", "build", *std_go_args(output: bin/"slack", ldflags:), "."

    generate_completions_from_executable(bin/"slack", "completion", shells: [:bash, :zsh, :fish, :pwsh], base_name: "slack")
  end
end
