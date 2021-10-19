class Kubectx < Formula
  desc "Tool that can switch between kubectl contexts easily and create aliases"
  homepage "https://github.com/ahmetb/kubectx"
  license "Apache-2.0"
  head "https://github.com/ahmetb/kubectx.git"

  def install
    bin.install "kubectx", "kubens"

    bash_completion.install "completion/kubectx.bash" => "kubectx"
    bash_completion.install "completion/kubens.bash" => "kubens"
    zsh_completion.install "completion/kubectx.zsh" => "_kubectx"
    zsh_completion.install "completion/kubens.zsh" => "_kubens"
    fish_completion.install "completion/kubectx.fish"
    fish_completion.install "completion/kubens.fish"
  end

  test do
    assert_match "USAGE:", shell_output("#{bin}/kubectx -h 2>&1")
    assert_match "USAGE:", shell_output("#{bin}/kubens -h 2>&1")
  end
end
