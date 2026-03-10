class Clok < Formula
  desc "LLM-powered CLI with persistent memory (Claude)"
  homepage "https://github.com/raitama1122/clok"
  url "https://github.com/raitama1122/clok/archive/refs/tags/v1.0.6.tar.gz"
  sha256 "e744d68d3ebff3259763812e9af2cc080a3aaaeed22718a2d4a2b86f909086c9"
  license "MIT"
  head "https://github.com/raitama1122/clok.git", branch: "main"

  depends_on :macos => :ventura
  depends_on :xcode => ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/clok"
  end

  test do
    assert_match "file_list", shell_output("#{bin}/clok setting tools 2>&1")
  end
end
