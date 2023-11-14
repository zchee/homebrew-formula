class HelmfileHead < Formula
  desc "Deploy Kubernetes Helm Charts"
  homepage "https://github.com/helmfile/helmfile"
  license "MIT"
  head "https://github.com/helmfile/helmfile.git", :branch => "main"

  depends_on "go" => :build

  def install
    revision = Utils.git_short_head
    ldflags = %W[
      -s -w
      -X go.szostok.io/version.version=v#{version}
      -X go.szostok.io/version.buildDate=#{time.iso8601}
      -X go.szostok.io/version.commit=#{revision}
      -X go.szostok.io/version.commitDate=#{time.iso8601}
      -X go.szostok.io/version.dirtyBuild=false
    ]
    system "go", "build", *std_go_args(ldflags: ldflags), "-o=#{bin}/helmfile"

    generate_completions_from_executable(bin/"helmfile", "completion", base_name: "helmfile")
  end
end
