class Clok < Formula
  desc "LLM-powered CLI with persistent memory (Claude)"
  homepage "https://github.com/raitama1122/clok"
  url "https://github.com/raitama1122/clok/archive/refs/tags/v1.0.3.tar.gz"
  sha256 "4f0fdc1691be2e58cce421b6041a4484568ea1e6bb3edd6ba153e276d4a7c959"
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
