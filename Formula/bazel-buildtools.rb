class BazelBuildtools < Formula
  desc "A bazel BUILD file formatter and editor"
  homepage "https://github.com/bazelbuild/buildtools"
  license "Apache-2.0"
  head "https://github.com/bazelbuild/buildtools.git"

  bottle :unneeded

  depends_on "bazelisk" => :build

  conflicts_with "buildifier", because: "Buildtools replaces the buildifier binary"
  conflicts_with "buildozer", because: "Buildtools replaces the buildozer binary"

  def install
    system "bazelisk", "build", "-c", "opt", "buildifier:buildifier", "buildifier2:buildifier2", "buildozer:buildozer", "generatetables:generatetables", "unused_deps:unused_deps"
    # system "bazelisk", "build", "--config=release", "buildifier:buildifier"
    # system "bazelisk", "build", "--config=release", "buildifier2:buildifier2"
    # system "bazelisk", "build", "--config=release", "buildozer:buildozer"
    # system "bazelisk", "build", "--config=release", "generatetables:generatetables"
    # system "bazelisk", "build", "--config=release", "unused_deps:unused_deps"
    bin.install "bazel-bin/buildifier/darwin_amd64_stripped/buildifier"
    bin.install "bazel-bin/buildifier2/darwin_amd64_stripped/buildifier2"
    bin.install "bazel-bin/buildozer/darwin_amd64_stripped/buildozer"
    bin.install "bazel-bin/generatetables/darwin_amd64_stripped/generatetables"
    bin.install "bazel-bin/unused_deps/darwin_amd64_stripped/unused_deps"
  end
end
