class Dirclean < Formula
  desc "Clean up old files from directories"
  homepage "https://github.com/arkag/dirclean"
  
  # Fetch latest release version
  def self.latest_version
    require "net/http"
    require "json"
    uri = URI("https://api.github.com/repos/arkag/dirclean/releases/latest")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    
    if response.code != "200"
      raise "GitHub API request failed with status #{response.code}: #{response.body}"
    end
    
    data = JSON.parse(response.body)
    if data["tag_name"]
      data["tag_name"].sub(/^v/, "")
    else
      raise "No tag_name found in GitHub response: #{response.body}"
    end
  rescue => e
    raise "Failed to fetch version: #{e.message}"
  end

  version latest_version

  # Define all possible binary combinations and config paths
  def self.config_path
    if OS.mac?
      "/usr/local/share/dirclean"
    else
      "/usr/share/dirclean"
    end
  end

  def self.binary_info
    {
      darwin_arm64: "dirclean-darwin-arm64.tar.gz",
      darwin_amd64: "dirclean-darwin-amd64.tar.gz",
      linux_arm64: "dirclean-linux-arm64.tar.gz",
      linux_amd64: "dirclean-linux-amd64.tar.gz"
    }
  end

  # Fetch SHA256 for a specific binary
  def self.fetch_checksum(version, binary)
    require "net/http"
    uri = URI("https://github.com/arkag/dirclean/releases/download/#{version}/checksums.txt")
    
    # Create HTTP client that follows redirects
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
    # Make request that follows redirects
    response = Net::HTTP.get_response(uri)
    while response.is_a?(Net::HTTPRedirection)
      uri = URI(response['location'])
      response = Net::HTTP.get_response(uri)
    end
    
    if !response.is_a?(Net::HTTPSuccess)
      raise "Failed to download checksums: HTTP #{response.code}"
    end
    
    # Debug output
    puts "Looking for checksum for: #{binary}"
    puts "Checksums content:"
    puts response.body
    
    response.body.each_line do |line|
      checksum, file = line.strip.split(/\s+/, 2)
      if file == binary
        puts "Found matching checksum: #{checksum} for #{file}"
        return checksum
      end
    end
    
    raise "Checksum not found for #{binary} in:\n#{response.body}"
  rescue => e
    raise "Failed to fetch checksum: #{e.message}"
  end

  on_macos do
    if Hardware::CPU.arm?
      binary = binary_info[:darwin_arm64]
      url "https://github.com/arkag/dirclean/releases/download/#{version}/#{binary}"
      sha256 fetch_checksum(version, binary)
    else
      binary = binary_info[:darwin_amd64]
      url "https://github.com/arkag/dirclean/releases/download/#{version}/#{binary}"
      sha256 fetch_checksum(version, binary)
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      binary = binary_info[:linux_arm64]
      url "https://github.com/arkag/dirclean/releases/download/#{version}/#{binary}"
      sha256 fetch_checksum(version, binary)
    else
      binary = binary_info[:linux_amd64]
      url "https://github.com/arkag/dirclean/releases/download/#{version}/#{binary}"
      sha256 fetch_checksum(version, binary)
    end
  end

  def install
    # Find and extract the tarball with debug output
    tarball = Dir["*.tar.gz"].first
    ohai "Found tarball: #{tarball}"
    
    # Extract with verbose output
    system "tar", "xvf", tarball
    
    unless $?.success?
      odie "Failed to extract #{tarball}"
    end
    
    # List contents of current directory
    system "ls", "-la"
    
    bin.install "dirclean"
    
    # Create config directory
    config_dir = etc/"dirclean"
    config_dir.mkpath
    
    # Install example config from the extracted archive
    config_file = "config/example.config.yaml"  # Adjust path based on your archive structure
    if File.exist?(config_file)
      (config_dir/"example.config.yaml").write(File.read(config_file))
    else
      odie "Config file not found at #{config_file}. Contents of current directory: #{Dir.entries('.')}"
    end
    
    # Create share directory and symlink
    share_dir = "#{HOMEBREW_PREFIX}/share/dirclean"
    system "mkdir", "-p", share_dir unless Dir.exist?(share_dir)
    system "ln", "-sf", "#{config_dir}/example.config.yaml", "#{share_dir}/example.config.yaml"
  end

  test do
    system "#{bin}/dirclean", "--version"
  end
end
