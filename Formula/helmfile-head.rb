class HelmfileHead < Formula
  desc "Declaratively deploy your Kubernetes manifests, Kustomize configs, and Charts as Helm releases."
  homepage "https://github.com/helmfile/helmfile"
  license "MIT"
  head "https://github.com/helmfile/helmfile.git", :branch => "main"

  depends_on "go" => :build

  def install
    revision = Utils.git_short_head
    ldflags = %W[
      -s -w
      -X go.szostok.io/version.version=#{version}
      -X go.szostok.io/version.commit=#{revision}
      -X go.szostok.io/version.dirtyBuild=false
    ]
    system "go", "build", *std_go_args(ldflags: ldflags), "-o=#{bin}/helmfile"

    # Install shell completions
    generate_completions_from_executable(bin/"helmfile", "completion", base_name: "helmfile")
  end
end
