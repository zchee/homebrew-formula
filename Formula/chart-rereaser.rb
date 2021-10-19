class ChartRereaser < Formula
  desc "Hosting Helm Charts via GitHub Pages and Releases"
  homepage "https://github.com/helm/chart-releaser/"
  head "https://github.com/helm/chart-releaser.git", branch: "main"

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s
      -w
      "-extldflags=-static"
      -X=github.com/helm/chart-releaser/cr/cmd.GitCommit=#{Utils.git_head}
      -X=github.com/helm/chart-releaser/cr/cmd.BuildDate=#{Date.today}
    ].join(" ")
    system "go", "build", *std_go_args, "-ldflags", ldflags, "-o", bin/"cr", "./cr/main.go"
  end

  test do
    system "#{bin}/cr version"
  end
end
