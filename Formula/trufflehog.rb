class Trufflehog < Formula
  desc "Find credentials all over the place"
  homepage "https://github.com/trufflesecurity/trufflehog"
  head "https://github.com/trufflesecurity/trufflehog.git", branch: "main"

  depends_on "go" => :build

  def install
    ldflags = "-X github.com/trufflesecurity/trufflehog/v3/pkg/version.BuildVersion=#{Utils.git_head}"
    system "go", "build", *std_go_args(ldflags: ldflags)
  end
end
