class K6Head < Formula
  desc "Modern load testing tool, using Go and JavaScript"
  homepage "https://k6.io"
  head "https://github.com/grafana/k6.git", branch: "master"
  license "AGPL-3.0-or-later"

  depends_on "go" => :build

  def install
    # CGO_ENABLED=0 go build -o dist/k6-v0.43.1-51-ge5653169-linux-amd64/k6 -trimpath -ldflags -X go.k6.io/k6/lib/consts.VersionDetails=2023-03-06T08:21:05+0000/v0.43.1-51-ge5653169
    revision = Utils.git_short_head
    ldflags = %W[
      -s -w
      -X go.k6.io/k6/lib/consts.VersionDetails=#{revision}
    ]
    puts *std_go_args
    system "go", "build", "-mod=vendor", "-trimpath", "-o=#{prefix}/bin/k6", "-ldflags", ldflags.join(" ")

    # Install bash completion
    output = Utils.safe_popen_read(bin/"k6", "completion", "bash")
    (bash_completion/"k6").write output

    # Install zsh completion
    output = Utils.safe_popen_read(bin/"k6", "completion", "zsh")
    (zsh_completion/"_k6").write output

    # Install fish completion
    output = Utils.safe_popen_read(bin/"k6", "completion", "fish")
    (fish_completion/"k6.fish").write output
  end

  test do
    (testpath/"whatever.js").write <<~EOS
      export default function() {
        console.log("whatever");
      }
    EOS

    assert_match "whatever", shell_output("#{bin}/k6 run whatever.js 2>&1")
    assert_match version.to_s, shell_output("#{bin}/k6 version")
  end
end
