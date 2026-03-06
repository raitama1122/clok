class Clok < Formula
  desc "LLM-powered CLI with persistent memory (Claude)"
  homepage "https://github.com/raitama1122/clok"
  url "https://github.com/raitama1122/clok/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "b1f21f447ebc439bb05f53afce8fff5c3eba44faf5cf5675279b675be22f64d0"
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
