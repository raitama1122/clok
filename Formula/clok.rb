# Homebrew formula for CLOK
# https://github.com/raitama1122/clok

class Clok < Formula
  desc "LLM-powered CLI with persistent memory (Claude)"
  homepage "https://github.com/raitama1122/clok"
  url "https://github.com/raitama1122/clok/archive/refs/heads/main.tar.gz"
  version "1.0.0"
  sha256 "df0fccb1554fd5d6cf26801f012fed2b646ba4ec208943a8dcc6551b05f041e4"
  license "MIT"
  head "https://github.com/raitama1122/clok.git", branch: "main"

  depends_on :macos => :ventura
  depends_on :xcode => ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/clok"
  end

  test do
    # CLOK shows tools list (works without API key)
    assert_match "file_list", shell_output("#{bin}/clok setting tools 2>&1")
  end
end
