class DockerLanguageServer < Formula
  desc "Language server for Dockerfiles, Compose files, and Bake files"
  homepage "https://github.com/docker/docker-language-server"
  license "Apache-2.0"
  head "https://github.com/docker/docker-language-server.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "go" => :build

  def install
    inreplace "build.sh", "OUTPUT=\"docker-language-server-${GOOS}-${GOARCH}\"", "OUTPUT=\"docker-language-server\""
    system "./build.sh"
    bin.install "docker-language-server"

    generate_completions_from_executable(bin/"docker-language-server", "completion")
  end
end
