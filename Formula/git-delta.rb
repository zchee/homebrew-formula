class GitDelta < Formula
  desc "Syntax-highlighting pager for git and diff output"
  homepage "https://github.com/dandavison/delta"
  license "MIT"
  head "https://github.com/dandavison/delta.git"

  bottle :unneeded

  depends_on "rust" => :build
  uses_from_macos "llvm"

  conflicts_with "delta", because: "both install a `delta` binary"

  def install
    ENV.append_to_cflags "-fno-stack-check" if DevelopmentTools.clang_build_version >= 1010
    system "cargo", "install", *std_cargo_args, "--all-features"
  end

  test do
    assert_match "delta #{version}", `#{bin}/delta --version`.chomp
  end
end
