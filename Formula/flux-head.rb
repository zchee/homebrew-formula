class FluxHead < Formula
  desc "Open and extensible continuous delivery solution for Kubernetes. Powered by GitOps Toolkit."
  homepage "https://fluxcd.io/"
  license "Apache-2.0"
  head "https://github.com/fluxcd/flux2.git", branch: "main"

  depends_on "go" => :build
  depends_on "kustomize" => :build

  def install
    system "make", "build"
    bin.install "bin/flux" => "flux-head"

    # Install bash completion
    output = Utils.safe_popen_read(bin/"flux-head", "completion", "bash")
    (bash_completion/"flux-head").write output
    inreplace (bash_completion/"flux-head"), "complete -o default -F __start_flux flux", "complete -o default -F __start_flux flux-head"
    inreplace (bash_completion/"flux-head"), "complete -o default -o nospace -F __start_flux flux", "complete -o default -o nospace -F __start_flux flux-head"

    # Install zsh completion
    output = Utils.safe_popen_read(bin/"flux-head", "completion", "zsh")
    (zsh_completion/"_flux-head").write output
    inreplace (zsh_completion/"_flux-head"), "#compdef flux", "#compdef flux-head"
    inreplace (zsh_completion/"_flux-head"), "compdef _flux flux", "compdef _flux flux-head"
  end
end
