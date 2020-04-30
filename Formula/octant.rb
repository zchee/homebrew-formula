require "language/node"

class Octant < Formula
  desc "Visualize your Kubernetes workloads"
  homepage "https://octant.dev"
  head "https://github.com/vmware-tanzu/octant.git"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "protoc-gen-go" => :build

  patch :DATA

  def install
    ENV["GOPATH"] = buildpath
    ENV["GOFLAGS"] = "-mod=vendor"

    dir = buildpath/"src/github.com/vmware-tanzu/octant"
    dir.install buildpath.children

    cd "src/github.com/vmware-tanzu/octant" do
      system "go", "run", "build.go", "go-install"

      ENV.prepend_path "PATH", buildpath/"bin"
      ENV.prepend_path "PATH", "#{Formula["node"].opt_libexec}/bin"
      ENV["NG_CLI_ANALYTICS"] = "false"
      cd "web" do
        system "npm", "install", *Language::Node.local_npm_install_args if build.head?
      end
      system "go", "run", "build.go", "ci-quick"
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

__END__
diff --git a/web/package.json b/web/package.json
index 119db778..6e14f449 100644
--- a/web/package.json
+++ b/web/package.json
@@ -102,5 +102,8 @@
     "tslint-plugin-prettier": "^2.3.0",
     "typescript": "^3.8.3",
     "wait-on": "^4.0.1"
+  },
+  "resolutions": {
+    "**/**/fsevents": "^2.1.3"
   }
 }
