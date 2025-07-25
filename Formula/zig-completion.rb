class ZigCompletion < Formula
  desc "Shell completions for the Zig compiler."
  homepage "https://github.com/ziglang/shell-completions"
  head "https://github.com/ziglang/shell-completions.git", branch: "master"

  def install
    bash_completion.install "_zig.bash"
    zsh_completion.install "_zig"
  end
end
