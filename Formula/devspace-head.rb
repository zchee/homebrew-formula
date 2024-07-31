require "language/node"

class DevspaceHead < Formula
  desc "CLI helps develop/deploy/debug apps with Docker and k8s"
  homepage "https://devspace.sh/"
  license "Apache-2.0"
  head "https://github.com/devspace-sh/devspace.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "kubernetes-cli" => :optional

  def install
    inreplace "hack/build-ui.bash" do |s|
      s.gsub!("npm install", "npm install --legacy-peer-deps --no-package-lock")
      s.gsub!("npm run build", "NODE_OPTIONS='--openssl-legacy-provider' npm run build")
    end
    system "hack/build-ui.bash"

    inreplace "hack/build-all.bash" do |s|
      s.gsub!("mv ui.tar.gz ", "# mv ui.tar.gz ")
      s.gsub!("$GOPATH/bin/go-bindata", "go run -mod=mod github.com/go-bindata/go-bindata/go-bindata@latest")
    end

    revision = Utils.git_short_head
    ldflags = "-s -w -X main.commitHash=#{revision} -X main.version=#{version}"
    system "go", "build", *std_go_args(output: bin/"devspace", ldflags: ldflags)

    generate_completions_from_executable(bin/"devspace", "completion", base_name: "devspace")
  end

  test do
    help_output = "DevSpace accelerates developing, deploying and debugging applications with Docker and Kubernetes."
    assert_match help_output, shell_output("#{bin}/devspace --help")

    init_help_output = "Initializes a new devspace project"
    assert_match init_help_output, shell_output("#{bin}/devspace init --help")

    assert_match version.to_s, shell_output("#{bin}/devspace version")
  end
end
