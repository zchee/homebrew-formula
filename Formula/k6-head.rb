class K6Head < Formula
  desc "Modern load testing tool, using Go and JavaScript"
  homepage "https://k6.io"
  head "https://github.com/grafana/k6.git", branch: "master"
  license "AGPL-3.0-or-later"

  depends_on "go" => :build

  def install
    revision = Utils.git_short_head
    ldflags = %W[
      -s -w
      -X go.k6.io/k6/lib/consts.VersionDetails=#{revision}
    ]
    puts *std_go_args
    system "go", "build", "-mod=vendor", "-trimpath", "-o=#{prefix}/bin/k6", "-ldflags", ldflags.join(" ")

    generate_completions_from_executable(bin/"k6", "completion")
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
