class BazelBuildtools < Formula
  desc "A bazel BUILD file formatter and editor"
  homepage "https://github.com/bazelbuild/buildtools"
  license "Apache-2.0"
  head "https://github.com/bazelbuild/buildtools.git", branch: "master"

  depends_on "bazelisk" => :build

  conflicts_with "buildifier", because: "Buildtools replaces the buildifier binary"
  conflicts_with "buildozer", because: "Buildtools replaces the buildozer binary"

  def install
    system "bazelisk", "build", "-c", "opt", "buildifier:buildifier", "buildifier2:buildifier2", "buildozer:buildozer", "generatetables:generatetables", "unused_deps:unused_deps"
    bin.install "bazel-bin/buildifier/buildifier_/buildifier"
    bin.install "bazel-bin/buildifier2/buildifier2_/buildifier2"
    bin.install "bazel-bin/buildozer/buildozer_/buildozer"
    bin.install "bazel-bin/generatetables/generatetables_/generatetables"
    bin.install "bazel-bin/unused_deps/unused_deps_/unused_deps"
  end
end
