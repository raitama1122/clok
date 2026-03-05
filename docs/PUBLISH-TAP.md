# Publish Homebrew Tap — Final Step

The tap is ready at `/opt/homebrew/Library/Taps/raitama1122/homebrew-tap/`.

**Important:** The CLOK repo was updated to include `Packages/linenoise-swift` as regular files (not a submodule) so the Homebrew build works. Push the CLOK changes first, then update the formula's sha256.

## 1. Push CLOK repo changes

```bash
cd /Users/bachtiarrifai/Documents/CLOK
git commit -m "Add Homebrew formula, include linenoise-swift, add docs"
git push origin main
```

## 2. Update formula sha256 (after pushing CLOK)

```bash
# Get new sha256 for the updated archive
curl -sL "https://github.com/raitama1122/clok/archive/refs/heads/main.tar.gz" | shasum -a 256

# Edit the formula and update the sha256 line
# Then commit in the tap:
cd /opt/homebrew/Library/Taps/raitama1122/homebrew-tap
# Update Formula/clok.rb with new sha256
git add Formula/clok.rb && git commit -m "Update clok sha256"
```

## 3. Create the homebrew-tap repo on GitHub

Go to https://github.com/new and create a repository named **homebrew-tap** (must be exactly this name).

- Owner: raitama1122
- Repo name: homebrew-tap
- Public
- Do **not** initialize with README (the tap already has content)

## 4. Push the tap

```bash
cd /opt/homebrew/Library/Taps/raitama1122/homebrew-tap
git push -u origin main
```

If you use SSH:
```bash
git remote set-url origin git@github.com:raitama1122/homebrew-tap.git
git push -u origin main
```

## 5. Test the install

```bash
brew install raitama1122/tap/clok
clok setting tools  # verify it works
```

## Done!

Users can now install CLOK with:
```bash
brew install raitama1122/tap/clok
```
