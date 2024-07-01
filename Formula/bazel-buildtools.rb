class BazelBuildtools < Formula
  desc "A bazel BUILD file formatter and editor"
  homepage "https://github.com/bazelbuild/buildtools"
  license "Apache-2.0"
  head "https://github.com/bazelbuild/buildtools.git", branch: "main"

  depends_on "go" => :build

  conflicts_with "buildifier", because: "Buildtools replaces the buildifier binary"
  conflicts_with "buildozer", because: "Buildtools replaces the buildozer binary"

  def install
    system "go", "build", *std_go_args, "-o", bin/"buildifier", "./buildifier"
    system "go", "build", *std_go_args, "-o", bin/"buildifier2", "./buildifier2"
    system "go", "build", *std_go_args, "-o", bin/"buildozer", "./buildozer"
  end
end
