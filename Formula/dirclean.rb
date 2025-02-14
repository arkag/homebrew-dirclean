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
  arch = Hardware::CPU.arm? ? "arm64" : "amd64"
  binary_name = "dirclean-#{os}-#{arch}.tar.gz"
  
  url "https://github.com/arkag/dirclean/releases/download/#{version}/#{binary_name}"
  sha256 checksums[binary_name]

  def install
    bin.install "dirclean"
    
    # Extract example config from the tarball
    system "tar", "-xf", "#{binary_name}", "example.config.yaml"
    
    if File.exist?("example.config.yaml")
      # Use etc.install to handle config file installation
      etc.install "example.config.yaml" => "dirclean/example.config.yaml"
    else
      odie "Config file not found in tarball. Contents: #{Dir.entries('.')}"
    end
    
    # Use prefix.install_symlink for creating the symlink
    prefix.install_symlink etc/"dirclean/example.config.yaml" => "share/dirclean/example.config.yaml"
  end

  test do
    system "#{bin}/dirclean", "--version"
  end
end
