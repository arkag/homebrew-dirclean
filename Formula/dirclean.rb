class Dirclean < Formula
  desc "Clean up old files from directories"
  homepage "https://github.com/arkag/dirclean"
  
  def self.release_info
    require "net/http"
    require "json"
    require "open-uri"
    
    version_uri = URI("https://api.github.com/repos/arkag/dirclean/releases/latest")
    http = Net::HTTP.new(version_uri.host, version_uri.port)
    http.use_ssl = true
    version_response = http.request(Net::HTTP::Get.new(version_uri))
    
    if version_response.code != "200"
      raise "GitHub API request failed with status #{version_response.code}"
    end
    
    data = JSON.parse(version_response.body)
    version = data["tag_name"] or raise "No tag_name found in GitHub response"
    
    checksums = {}
    URI("https://github.com/arkag/dirclean/releases/download/#{version}/checksums.txt").open do |f|
      f.each_line do |line|
        checksum, file = line.strip.split(/\s+/, 2)
        checksums[file] = checksum if file && checksum
      end
    end
    
    [version, checksums]
  rescue => e
    raise "Failed to fetch release info: #{e.message}"
  end

  version, checksums = release_info
  os = OS.mac? ? "darwin" : "linux"
  binary_name = "dirclean-#{os}-#{Hardware::CPU.arch}64.tar.gz"
  
  url "https://github.com/arkag/dirclean/releases/download/#{version}/#{binary_name}"
  sha256 checksums[binary_name]

  def install
    bin.install "dirclean"
    
    config_dir = etc/"dirclean"
    config_dir.mkpath
    
    config_file = "config/example.config.yaml"
    if File.exist?(config_file)
      (config_dir/"example.config.yaml").write(File.read(config_file))
    else
      odie "Config file not found at #{config_file}. Contents of current directory: #{Dir.entries('.')}"
    end
    
    share_dir = "#{HOMEBREW_PREFIX}/share/dirclean"
    mkdir_p share_dir
    ln_sf "#{config_dir}/example.config.yaml", "#{share_dir}/example.config.yaml"
  end

  test do
    system "#{bin}/dirclean", "--version"
  end
end
