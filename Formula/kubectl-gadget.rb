class KubectlGadget < Formula
  desc "Collection of gadgets for Kubernetes developers"
  homepage "https://www.inspektor-gadget.io/"
  license "Apache-2.0"
  head "https://github.com/inspektor-gadget/inspektor-gadget.git", branch: "main"

  depends_on "go" => :build

  def install
    os = OS.kernel_name.downcase
    arch = Hardware::CPU.intel? ? "amd64" : Hardware::CPU.arch.to_s

    system "make", "kubectl-gadget-#{os}-#{arch}"
    bin.install "kubectl-gadget-#{os}-#{arch}" => "kubectl-gadget"

    (bin/"kubectl_complete-gadget").write <<~EOS
      #!/usr/bin/env sh
    
      kubectl gadget __complete "$@"
    EOS
  end
end
