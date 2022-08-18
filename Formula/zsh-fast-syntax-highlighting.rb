class ZshFastSyntaxHighlighting < Formula
  desc "Fast Zsh Syntax Highlighting"
  homepage "https://github.com/zdharma/fast-syntax-highlighting"
  head "https://github.com/zdharma/fast-syntax-highlighting.git", branch: "master"

  def install
    pkgshare.install Dir["*"]
  end

  def caveats
    <<~EOS
      To activate the syntax highlighting, add the following at the end of your .zshrc:
        source #{HOMEBREW_PREFIX}/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
    EOS
  end

  test do
    assert_match "#{version}\n",
      shell_output("zsh -c '. #{pkgshare}/fast-syntax-highlighting.plugin.zsh && echo $FAST_HIGHLIGHT_VERSION'")
  end
end
