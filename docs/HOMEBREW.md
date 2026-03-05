# Publishing CLOK to Homebrew

## Prerequisites

- GitHub repo with CLOK
- [Homebrew](https://brew.sh) installed
- [GitHub CLI](https://cli.github.com/) (`brew install gh`)

## 1. Create a GitHub release

Tag a version for users to install:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or create a release on GitHub: https://github.com/raitama1122/CLOK/releases/new

## 2. Create your Homebrew tap

```bash
brew tap-new raitama1122/homebrew-tap
```

This creates a local tap at `$(brew --repository raitama1122/homebrew-tap)`.

## 3. Add the formula

```bash
# Copy the formula
cp Formula/clok.rb $(brew --repository raitama1122/homebrew-tap)/Formula/

# Edit the formula: update url, version, and sha256
# Get sha256 for your release tarball:
curl -sL https://github.com/raitama1122/CLOK/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
```

## 4. Update the formula

Edit `Formula/clok.rb`:

- Replace `your-username` with your GitHub username
- Set the correct `url` (e.g. `https://github.com/raitama1122/CLOK/archive/refs/tags/v1.0.0.tar.gz`)
- Set `sha256` from the command above

## 5. Test locally

```bash
brew install --build-from-source raitama1122/homebrew-tap/clok
clok --help  # or just run clok
brew uninstall clok
```

## 6. Push to GitHub

```bash
gh repo create raitama1122/homebrew-tap --push --public --source "$(brew --repository raitama1122/homebrew-tap)"
```

Or manually add the remote and push:

```bash
cd $(brew --repository raitama1122/homebrew-tap)
git remote add origin https://github.com/raitama1122/homebrew-tap.git
git push -u origin main
```

## 7. Install for users

Users can install with:

```bash
brew install raitama1122/homebrew-tap/clok
```

Or add to your README:

```markdown
## Install

brew install raitama1122/homebrew-tap/clok
```

## Updating

When you release a new version:

1. Create a new tag (e.g. `v1.1.0`)
2. Update the formula's `url` and `sha256`
3. Commit and push to your tap

```bash
# Get new sha256
curl -sL https://github.com/raitama1122/CLOK/archive/refs/tags/v1.1.0.tar.gz | shasum -a 256
```

## Optional: GitHub Actions for bottles

To build pre-compiled binaries (bottles) for faster installs, add `.github/workflows` from the tap template. Run `brew tap-new` and it will create workflow files for you.
