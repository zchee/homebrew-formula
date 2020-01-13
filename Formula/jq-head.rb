class JqHead < Formula
  include Language::Python::Virtualenv

  desc "Lightweight and flexible command-line JSON processor"
  homepage "https://stedolan.github.io/jq/"

  head do
    url "https://github.com/stedolan/jq.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "python" => :build
    depends_on "pipenv" => :build

    resource "lxml" do
      url "https://files.pythonhosted.org/packages/e4/19/8dfeef50623892577dc05245093e090bb2bab4c8aed5cad5b03208959563/lxml-4.4.2.tar.gz"
      sha256 "eff69ddbf3ad86375c344339371168640951c302450c5d3e9936e98d6459db06"
    end
  end

  # depends_on "oniguruma"

  def install
    # if build.head?
    #   venv = virtualenv_create(buildpath/"lxml", "python3")
    #   venv.pip_install "lxml"
    #
    #   xy = Language::Python.major_minor_version "python3"
    #   ENV["PYTHONPATH"] = libexec/"lib/python#{xy}/site-packages"
    #   ENV["STATIC_DEPS"] = "true"
    #   ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python#{xy}/site-packages"
    #  
    #   resources.each do |r|
    #     r.stage do
    #       system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    #     end
    #   end
    #  
    #   ENV.prepend_create_path "PYTHONPATH", libexec/"lib/python#{xy}/site-packages"
    #   system "python3", *Language::Python.setup_install_args(libexec)
    #
    #   bin.install Dir[libexec/"bin/*"]
    #   env = {
    #     :PATH       => "#{Formula["jq"].opt_bin}:$PATH",
    #     :PYTHONPATH => ENV["PYTHONPATH"],
    #   }
    #   bin.env_script_all_files(libexec/"bin", env)
    # end

    system "autoreconf", "-iv" if build.head?
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--disable-maintainer-mode",
                          "--disable-docs",
                          "--prefix=#{prefix}"

    system "make", "install"
  end

  test do
    assert_equal "2\n", pipe_output("#{bin}/jq .bar", '{"foo":1, "bar":2}')
  end
end
