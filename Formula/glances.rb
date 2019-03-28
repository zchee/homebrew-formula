class Glances < Formula
  desc "Alternative to top/htop"
  homepage "https://nicolargo.github.io/glances/"
  url "https://github.com/nicolargo/glances/archive/v3.0.2.tar.gz"
  sha256 "76a793a8e0fbdce11ad7fb35000695fdb70750f937db41f820881692d5b0a29c"
  head "https://github.com/nicolargo/glances.git"

  depends_on "python"
  depends_on "pandoc"

  resource "psutil" do
    url "https://files.pythonhosted.org/packages/7d/9a/1e93d41708f8ed2b564395edfa3389f0fd6d567597401c2e5e2775118d8b/psutil-5.4.7.tar.gz"
    sha256 "5b6322b167a5ba0c5463b4d30dfd379cd4ce245a1162ebf8fc7ab5c5ffae4f3b"
  end

  resource "bernhard" do
    url "https://files.pythonhosted.org/packages/51/d4/b2701097f9062321262c4d4e3488fdf127887502b2619e8fd1ae13955a36/bernhard-0.2.6.tar.gz"
    sha256 "7efafa3ae1221a465fcbd74c4f78e5ad4a1841b9fa70c95eb38ba103a71bdb9b"
  end

  resource "bottle" do
    url "https://files.pythonhosted.org/packages/38/6d/593c8338851a249c9981322bab2bcffade1101127dce27d4c682ed234558/bottle-0.12.15.tar.gz"
    sha256 "b5529f8956682320b90f518041269784a37770d5fcc1ae6d70d288e9fc060fbc"
  end

  resource "cassandra-driver" do
    url "https://files.pythonhosted.org/packages/31/07/2423f77878559593ef17175ef2e0372dc91994368b15c6a47fca40b416ea/cassandra-driver-3.16.0.tar.gz"
    sha256 "42bcb167a90da6604081872ef609a327a63273842da81120fc462de031155abe"
  end

  resource "couchdb" do
    url "https://files.pythonhosted.org/packages/7c/c8/f94a107eca0c178e5d74c705dad1a5205c0f580840bd1b155cd8a258cb7c/CouchDB-1.2.tar.gz"
    sha256 "1386a1a43f25bed3667e3b805222054940d674fa1967fa48e9d2012a18630ab7"
  end

  resource "elasticsearch" do
    url "https://files.pythonhosted.org/packages/9d/ce/c4664e8380e379a9402ecfbaf158e56396da90d520daba21cfa840e0eb71/elasticsearch-6.3.1.tar.gz"
    sha256 "aada5cfdc4a543c47098eb3aca6663848ef5d04b4324935ced441debc11ec98b"
  end

  resource "influxdb" do
    url "https://files.pythonhosted.org/packages/62/ff/f3927023d5ef2ee4156a54ff87757eaff1f630aed6c0c4fbd1c1413bfb88/influxdb-5.2.0.tar.gz"
    sha256 "3ba558432d4c64293ada0deccf76527777e76750e99176d3b9dbc5a72bd4163b"
  end

  resource "kafka-python" do
    url "https://files.pythonhosted.org/packages/92/43/a88add4e70f14b11c533dfa04df77a17b8c936bdc0b119c5ad151a010fa1/kafka-python-1.4.4.tar.gz"
    sha256 "2014bbbe618f3224e68b07cf9b44c702b28913c551e6f63246bf9b4477ca3add"
  end

  resource "netifaces" do
    url "https://files.pythonhosted.org/packages/81/39/4e9a026265ba944ddf1fea176dbb29e0fe50c43717ba4fcf3646d099fe38/netifaces-0.10.7.tar.gz"
    sha256 "bd590fcb75421537d4149825e1e63cca225fd47dad861710c46bd1cb329d8cbd"
  end

  resource "nvidia-ml-py3" do
    url "https://files.pythonhosted.org/packages/6d/64/cce82bddb80c0b0f5c703bbdafa94bfb69a1c5ad7a79cff00b482468f0d3/nvidia-ml-py3-7.352.0.tar.gz"
    sha256 "390f02919ee9d73fe63a98c73101061a6b37fa694a793abf56673320f1f51277"
  end

  resource "pika" do
    url "https://files.pythonhosted.org/packages/ac/a0/e9a0268094e0b569b03153fd11b9b9f54c4df8d7917c55550edbcdf8b55e/pika-0.12.0.tar.gz"
    sha256 "306145b8683e016d81aea996bcaefee648483fc5a9eb4694bb488f54df54a751"
  end

  resource "potsdb" do
    url "https://files.pythonhosted.org/packages/14/dd/c7c618f87cb6005adf86eafa08e33f2e807dbd2128d992e53d5ee1a87cbc/potsdb-1.0.3.tar.gz"
    sha256 "ef8317e45758552c6fe15a5246f93afee6f40c1c7e08dc0469e70adf463ed447"
  end

  resource "prometheus_client" do
    url "https://files.pythonhosted.org/packages/61/84/9aa657b215b04f21a72ca8e50ff159eef9795096683e4581a357baf4dde6/prometheus_client-0.4.2.tar.gz"
    sha256 "046cb4fffe75e55ff0e6dfd18e2ea16e54d86cc330f369bebcc683475c8b68a9"
  end

  resource "py-cpuinfo" do
    url "https://files.pythonhosted.org/packages/75/d0/7e547b0abfa23234c82100d1bfe670286a3361f4382fc766329f70bc34e8/py-cpuinfo-4.0.0.tar.gz"
    sha256 "6615d4527118d4ea1db4d86dac4340725b3906aa04bf36b7902f7af4425fb25f"
  end

  resource "pygal" do
    url "https://files.pythonhosted.org/packages/14/52/2394f0f8444db3af299f2700aaff22f8cc3741fbd5ed644f782327d356b3/pygal-2.4.0.tar.gz"
    sha256 "9204f05380b02a8a32f9bf99d310b51aa2a932cba5b369f7a4dc3705f0a4ce83"
  end

  resource "pysnmp" do
    url "https://files.pythonhosted.org/packages/8b/66/96a49bf1d64ad1e005a8455644523b7e09663a405eb20a4599fb219e4c95/pysnmp-4.4.6.tar.gz"
    sha256 "e34ffa0dce5f69adabd478ff76c3e1b08e32ebb0767df8b178d0704f4a1ac406"
  end

  resource "pystache" do
    url "https://files.pythonhosted.org/packages/d6/fd/eb8c212053addd941cc90baac307c00ac246ac3fce7166b86434c6eae963/pystache-0.5.4.tar.gz"
    sha256 "f7bbc265fb957b4d6c7c042b336563179444ab313fb93a719759111eabd3b85a"
  end

  resource "pyzmq" do
    url "https://files.pythonhosted.org/packages/b9/6a/bc9277b78f5c3236e36b8c16f4d2701a7fd4fa2eb697159d3e0a3a991573/pyzmq-17.1.2.tar.gz"
    sha256 "a72b82ac1910f2cf61a49139f4974f994984475f771b0faa730839607eeedddf"
  end

  resource "requests" do
    url "https://files.pythonhosted.org/packages/40/35/298c36d839547b50822985a2cf0611b3b978a5ab7a5af5562b8ebe3e1369/requests-2.20.1.tar.gz"
    sha256 "ea881206e59f41dbd0bd445437d792e43906703fff75ca8ff43ccdb11f33f263"
  end

  resource "statsd" do
    url "https://files.pythonhosted.org/packages/2d/f2/48ffc8d0051849e4417e809dc9420e76084c8a62749b3442915402127caa/statsd-3.3.0.tar.gz"
    sha256 "e3e6db4c246f7c59003e51c9720a51a7f39a396541cb9b147ff4b14d15b5dd1f"
  end

  resource "zeroconf" do
    url "https://files.pythonhosted.org/packages/9a/a3/9e4bb6a8e5f807c1a817168c9985f9d3975725a71ae77eb47ce1db66ada7/zeroconf-0.21.3.tar.gz"
    sha256 "5b52dfdf4e665d98a17bf9aa50dea7a8c98e25f972d9c1d7660e2b978a1f5713"
  end

  def install
    xy = Language::Python.major_minor_version "python3"
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python#{xy}/site-packages"
    resource("psutil").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("bernhard").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("bottle").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("cassandra-driver").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("elasticsearch").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("influxdb").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("kafka-python").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("netifaces").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("nvidia-ml-py3").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("pika").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("potsdb").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("prometheus_client").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("py-cpuinfo").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("pygal").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("pysnmp").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("pystache").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("pyzmq").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("requests").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("statsd").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end
    resource("zeroconf").stage do
      system "python3", *Language::Python.setup_install_args(libexec/"vendor")
    end

    ENV.prepend_create_path "PYTHONPATH", libexec/"lib/python#{xy}/site-packages"
    system "python3", *Language::Python.setup_install_args(libexec)

    bin.install Dir[libexec/"bin/*"]
    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])

    prefix.install libexec/"share"
  end

  test do
    begin
      read, write = IO.pipe
      pid = fork do
        exec bin/"glances", "-q", "--export", "csv", "--export-csv", "/dev/stdout", :out => write
      end
      header = read.gets
      assert_match "timestamp", header
    ensure
      Process.kill("TERM", pid)
    end
  end
end
