class Dirclean < Formula
  desc "Clean up old files from directories"
  homepage "https://github.com/arkag/dirclean"

  def self.binary_name
    os = OS.mac? ? "darwin" : "linux"
    arch = Hardware::CPU.arm? ? "arm64" : "amd64"
    "dirclean-#{os}-#{arch}.tar.gz"
  end
  
  def self.release_info
    require "net/http"
    require "json"
    require "open-uri"
    
    version_uri = URI("https://api.github.com/repos/arkag/dirclean/releases/latest")
    http = Net::HTTP.new(version_uri.host, version_uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(version_uri)
    # Add User-Agent to avoid GitHub API rate limiting
    request["User-Agent"] = "Homebrew-dirclean-formula"
    version_response = http.request(request)
    
    if version_response.code != "200"
      raise "GitHub API request failed with status #{version_response.code}"
    end
    
    data = JSON.parse(version_response.body)
    version = data["tag_name"].gsub(/^v/, "") # Remove 'v' prefix if present
    
    if version.empty?
      raise "No tag_name found in GitHub response"
    end
    
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

  livecheck do
    url "https://api.github.com/repos/arkag/dirclean/releases/latest"
    regex(/tag_name": "v?(\d+(?:\.\d+)+)"/i)
    strategy :json
  end

  @version, @checksums = release_info
  version @version
  url "https://github.com/arkag/dirclean/releases/download/#{@version}/#{Dirclean.binary_name}"
  sha256 @checksums[Dirclean.binary_name]

  def install
    bin.install "dirclean"
    
    # Extract example config from the downloaded archive
    archive = cached_download
    system "tar", "-xf", archive, "example.config.yaml"
    
    if File.exist?("example.config.yaml")
      # Install config file to etc
      (etc/"dirclean").install "example.config.yaml"
      
      # Create symlink in share directory
      (share/"dirclean").mkpath
      (share/"dirclean").install_symlink etc/"dirclean/example.config.yaml"
    else
      odie "Config file not found in tarball. Contents: #{Dir.entries('.')}"
    end
  end

  test do
    system "#{bin}/dirclean", "--version"
  end
end
