class TiltHead < Formula
  desc "Define your dev environment as code. For microservice apps on Kubernetes"
  homepage "https://tilt.dev/"
  license "Apache-2.0"
  head "https://github.com/tilt-dev/tilt.git", branch: "master"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "yarn" => :build

  def install
    # bundling the frontend assets first will allow them to be embedded into
    # the final build
    system "yarn", "config", "set", "ignore-engines", "true" # allow our newer node
    system "make", "build-js"

    ldflags_version = Utils.safe_popen_read("git describe --abbrev=0 --tags").chomp
    ENV["CGO_ENABLED"] = "1"
    ENV["CGO_CFLAGS"] = "-Wno-deprecated-declarations"
    ldflags = %W[
      -s -w
      -X main.version=#{ldflags_version}-dev
      -X main.commit=#{Utils.git_head}
      -X main.date=#{time.iso8601}
    ]
    system "go", "build", "-tags=osusergo", "-mod=vendor", *std_go_args(output: bin/"tilt", ldflags: ldflags), "./cmd/tilt"

    generate_completions_from_executable(bin/"tilt", "completion", base_name: "tilt")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tilt version")

    assert_match "Error: No tilt apiserver found: tilt-default", shell_output("#{bin}/tilt api-resources 2>&1", 1)
  end
end
