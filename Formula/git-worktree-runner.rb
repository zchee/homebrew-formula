class GitWorktreeRunner < Formula
  desc "Bash-based Git worktree manager with editor and AI tool integration."
  homepage "https://github.com/coderabbitai/git-worktree-runner"
  license "Apache-2.0"
  head "https://github.com/coderabbitai/git-worktree-runner.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  def install
    inreplace "bin/git-gtr", 'exec "$SCRIPT_DIR/gtr" "$@"', 'exec "$SCRIPT_DIR/../libexec/gtr" "$@"'

    prefix.install ["adapters", "lib", "templates"]
    bin.install "bin/git-gtr"
    libexec.install "bin/gtr"
    zsh_completion.install "completions/_git-gtr"
  end
end
