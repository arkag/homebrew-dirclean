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

  livecheck do
    url :stable
    strategy :github_latest
  end

  @version, @checksums = release_info
  url "https://github.com/arkag/dirclean/releases/download/#{@version}/#{Dirclean.binary_name}"
  sha256 @checksums[Dirclean.binary_name]

  def install
    bin.install "dirclean"
    
    # Extract example config from the downloaded archive
    archive = cached_download
    system "tar", "-xf", archive, "example.config.yaml"
    
    if File.exist?("example.config.yaml")
      # Install the example config to both etc and share
      (etc/"dirclean").install "example.config.yaml"
      (share/"dirclean").install_symlink etc/"dirclean/example.config.yaml"
      
      # For compatibility with both Intel and Apple Silicon Macs
      if OS.mac?
        if Hardware::CPU.arm?
          # Ensure /opt/homebrew/share/dirclean exists and has the config
          (HOMEBREW_PREFIX/"share/dirclean").install_symlink etc/"dirclean/example.config.yaml"
        else
          # For Intel Macs, ensure /usr/local/share/dirclean exists and has the config
          (HOMEBREW_PREFIX/"share/dirclean").install_symlink etc/"dirclean/example.config.yaml"
        end
      end
    else
      odie "Config file not found in tarball. Contents: #{Dir.entries('.')}"
    end
  end

  test do
    system "#{bin}/dirclean", "--version"
  end
end
