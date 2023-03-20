class OrasHead < Formula
  desc "OCI Registry As Storage"
  homepage "https://github.com/oras-project/oras"
  head "https://github.com/oras-project/oras.git", branch: "main"
  license "Apache-2.0"

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = %W[
      -s -w
      -linkmode=external
      -buildid=
      -X oras.land/oras/internal/version.Version=#{version}
      -X oras.land/oras/internal/version.BuildMetadata=Homebrew
      "-extldflags=-static-pie -all_load -Wl,-no_deduplicate"
    ].join(" ")
    tags = %W[
      osusergo
      netgo
      static
    ].join(",")

    system "go", "build", "-buildmode=pie", "-tags=#{tags}", *std_go_args(ldflags: ldflags), "-o=#{bin}/oras", "./cmd/oras"

    bash_output = Utils.safe_popen_read(bin/"oras", "completion", "bash")
    (bash_completion/"oras").write bash_output
    zsh_output = Utils.safe_popen_read(bin/"oras", "completion", "zsh")
    (zsh_completion/"_oras").write zsh_output
    fish_output = Utils.safe_popen_read(bin/"oras", "completion", "fish")
    (fish_completion/"oras.fish").write fish_output
  end

  test do
    assert_match "#{version}+Homebrew", shell_output("#{bin}/oras version")

    port = free_port
    contents = <<~EOS
      {
        "key": "value",
        "this is": "a test"
      }
    EOS
    (testpath/"test.json").write(contents)

    # Although it might not make much sense passing the JSON as both manifest and payload,
    # it helps make the test consistent as the error can randomly switch between either hash
    output = shell_output("#{bin}/oras push localhost:#{port}/test-artifact:v1 " \
                          "--config test.json:application/vnd.homebrew.test.config.v1+json " \
                          "./test.json 2>&1", 1)
    assert_match "#{port}: connect: connection refused", output
  end
end
