class KubectxHead < Formula
  desc "Tool that can switch between kubectl contexts easily and create aliases"
  homepage "https://github.com/ahmetb/kubectx"
  license "Apache-2.0"
  head "https://github.com/ahmetb/kubectx.git", branch: "master"

  def install
    bin.install "kubectx", "kubens"
    bin.install_symlink "kubectx" => "kctx"
    bin.install_symlink "kubens" => "kns"

    ln_s bin/"kubectx", bin/"kubectl-ctx"
    ln_s bin/"kubens", bin/"kubectl-ns"

    %w[kubectx kubens].each do |cmd|
      bash_completion.install "completion/#{cmd}.bash" => cmd.to_s
      zsh_completion.install "completion/_#{cmd}.zsh" => "_#{cmd}"
      fish_completion.install "completion/#{cmd}.fish"
    end
  end

  test do
    assert_match "USAGE:", shell_output("#{bin}/kubectx -h 2>&1")
    assert_match "USAGE:", shell_output("#{bin}/kubens -h 2>&1")
  end
end
