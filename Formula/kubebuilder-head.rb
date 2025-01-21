class KubebuilderHead < Formula
  desc "SDK for building Kubernetes APIs using CRDs"
  homepage "https://github.com/kubernetes-sigs/kubebuilder"
  license "Apache-2.0"
  head "https://github.com/kubernetes-sigs/kubebuilder.git", branch: "master"

  depends_on "go" => :build

  def install
    system "make", "build"
    bin.install "bin/kubebuilder" => "kubebuilder"

    generate_completions_from_executable(bin/"kubebuilder", "completion", base_name: "kubebuilder")
  end

  test do
    mkdir "test" do
      system "go", "mod", "init", "example.com"
      system bin/"kubebuilder", "init",
                 "--plugins", "go.kubebuilder.io/v4",
                 "--project-version", "3",
                 "--skip-go-version-check"
    end

    assert_match <<~YAML, (testpath/"test/PROJECT").read
      domain: my.domain
      layout:
      - go.kubebuilder.io/v4
      projectName: test
      repo: example.com
      version: "3"
    YAML

    assert_match version.to_s, shell_output("#{bin}/kubebuilder version")
  end
end
