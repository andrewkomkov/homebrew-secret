class Secret < Formula
  desc "Keychain and Secure Enclave store for secrets an agent uses by name"
  homepage "https://github.com/andrewkomkov/secret-cli"
  url "https://github.com/andrewkomkov/secret-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "07d68b2dc530c88a472ba22104c4e254fa6da5905e3e8e71fa2625d37a0bcde9"
  license "MIT"

  depends_on :macos

  def install
    libexec.install "bin", "helper", "hooks", "completions", "docs", "app", "install.sh", "README.md", "LICENSE"
    (libexec/"build").mkpath

    # Helper of the Secure Enclave store; signed by an Apple Development certificate if there is one.
    system libexec/"helper/store/build.sh", "Release", libexec/"build"

    # Helper of Touch ID for the file keychain.
    auth = libexec/"build/secret-auth"
    system "swiftc", "-swift-version", "5", "-O", libexec/"helper/secret-auth.swift", "-o", auth
    system "codesign", "-f", "-s", "-", "-o", "runtime", auth
    (libexec/"build/secret-auth.src-sha256").write "#{Digest::SHA256.file(libexec/"helper/secret-auth.swift").hexdigest}\n"

    bin.install_symlink libexec/"bin/secret"
    zsh_completion.install_symlink libexec/"completions/_secret"
  end

  def caveats
    <<~EOS
      Create the keychain:
        secret init

      Claude Code hook and the menu bar app SecretBar (SecretBar needs Xcode):
        "$(brew --prefix secret)/libexec/install.sh" --claude-hook --app

      Without an Apple Development certificate the helpers are signed ad-hoc. After an
      upgrade that changes the store helper, secret asks for `secret touchid repair`.
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/secret help")
    kc = testpath/"test.keychain-db"
    system "security", "create-keychain", "-p", "test", kc
    ENV["SECRET_KEYCHAIN"] = kc.to_s
    ENV["SECRET_NO_DIALOG"] = "1"
    ENV["SECRET_LOG"] = (testpath/"access.log").to_s
    ENV["SECRET_NAMES_CACHE"] = (testpath/"names").to_s
    pipe_output("#{bin}/secret set T_A", "value-1")
    assert_match "T_A", shell_output("#{bin}/secret ls")
    assert_equal "ok\n", shell_output("#{bin}/secret run --mask T_A -- sh -c '[ \"$T_A\" = value-1 ] && echo ok'")
  ensure
    system "security", "delete-keychain", kc if kc&.exist?
  end
end
