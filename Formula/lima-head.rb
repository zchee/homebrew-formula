class LimaHead < Formula
  desc "Linux virtual machines"
  homepage "https://github.com/lima-vm/lima"
  head "https://github.com/lima-vm/lima.git", branch: "master"
  license "Apache-2.0"

  depends_on "go" => :build
  depends_on "qemu"
  depends_on "bash" => :build

  def install
    inreplace "Makefile" do |s|
      s.gsub! "codesign -f -v --entitlements vz.entitlements -s - $@", "codesign -f -v --entitlements vz.entitlements -s - $@ || true"
      s.gsub! "codesign --entitlements vz.entitlements -s - $<", "codesign --entitlements vz.entitlements -s - $< || true"
    end

    ENV["SHELL"] = "#{Formula["bash"].opt_bin}/bash"
    system "make", "clean", "binaries"

    bin.install Dir["_output/bin/*"]
    share.install Dir["_output/share/*"]

    # Install shell completions
    generate_completions_from_executable(bin/"limactl", "completion", base_name: "limactl")
  end

  test do
    assert_match "Pruning", shell_output("#{bin}/limactl prune 2>&1")
  end
end
