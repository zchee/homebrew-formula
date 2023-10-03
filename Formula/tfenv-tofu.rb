class TfenvTofu < Formula
  desc "Terraform and OpenTofu version manager"
  homepage "https://github.com/opentofu/tfenv"
  license "MIT"
  head "https://github.com/opentofu/tfenv.git", branch: "add-opentofu-support"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  uses_from_macos "unzip"

  on_macos do
    depends_on "grep"
  end

  conflicts_with "terraform", because: "tfenv symlinks terraform binaries"
  conflicts_with "tfenv", because: "OpenTofu fork"

  def install
    prefix.install %w[bin lib libexec share]
  end

  test do
    assert_match "0.10.0", shell_output("#{bin}/tfenv list-remote")
    with_env(TFENV_TERRAFORM_VERSION: "0.10.0", TF_AUTO_INSTALL: "false") do
      assert_equal "0.10.0", shell_output("#{bin}/tfenv version-name").strip
    end
  end
end
