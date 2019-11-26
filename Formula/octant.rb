require "language/node"

class Octant < Formula
  desc "Kubernetes introspection tool for developers"
  homepage "https://github.com/vmware/octant"
  head "https://github.com/vmware-tanzu/octant.git"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "protoc-gen-go" => :build

  def install
    ENV["GOPATH"] = buildpath
    ENV["GOFLAGS"] = "-mod=vendor"

    dir = buildpath/"src/github.com/vmware-tanzu/octant"
    dir.install buildpath.children

    cd "src/github.com/vmware-tanzu/octant" do
      system "go", "run", "build.go", "go-install"
      ENV.prepend_path "PATH", buildpath/"bin"

      ENV.prepend_path "PATH", "#{Formula["node"].opt_libexec}/bin"
      cd "web" do
        system "npm", "install", "fsevents@2.1.1", "--save-dev", *Language::Node.local_npm_install_args if build.head?
        system "rm", "-rf", "node_modules"
      end
      system "go", "run", "build.go", "web-build"
      system "go", "run", "build.go", "generate"

      commit = Utils.popen_read("git rev-parse HEAD").chomp
      build_time = Utils.popen_read("date -u +'%Y-%m-%dT%H:%M:%SZ' 2> /dev/null").chomp
      ldflags = ["-X \"main.version=#{version}\"",
                 "-X \"main.gitCommit=#{commit}\"",
                 "-X \"main.buildTime=#{build_time}\""]

      ENV["GO_LDFLAGS"] = ldflags.join(" ")
      system "go", "run", "build.go", "build"
      # system "go", "build", "-o", bin/"octant", "-ldflags", ldflags.join(" "),
      #         "-v", "./cmd/octant"
      bin.install "build/octant"
    end
  end

  test do
    kubeconfig = testpath/"config"
    output = shell_output("#{bin}/octant --kubeconfig #{kubeconfig} 2>&1", 1)
    assert_match "failed to init cluster client", output

    assert_match version.to_s, shell_output("#{bin}/octant version")
  end
end
