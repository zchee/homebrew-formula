class KubectlValidate < Formula
  desc "kubectl-validate is a SIG-CLI subproject to support the local validation of resources for native Kubernetes types and CRDs."
  homepage "https://github.com/kubernetes-sigs/kubectl-validate"
  license "Apache-2.0"
  head "https://github.com/kubernetes-sigs/kubectl-validate.git", branch: "main"

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = "-s -w"
    system "go", "build", *std_go_args(ldflags: ldflags)

    (bin/"kubectl_complete-validate").write <<~EOS
      #!/usr/bin/env sh
    
      kubectl validate __complete "$@"
    EOS
  end
end
