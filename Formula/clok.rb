class Clok < Formula
  desc "LLM-powered CLI with persistent memory (Claude)"
  homepage "https://github.com/raitama1122/clok"
  url "https://github.com/raitama1122/clok/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "de5ab6f0f9254d5df5175f15ca9b4b5afa78858f1b6ea11f055d898ddaf9c6bc"
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
