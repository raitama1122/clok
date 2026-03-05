# Publish Homebrew Tap — Final Step

The tap is ready at `/opt/homebrew/Library/Taps/raitama1122/homebrew-tap/`. CLOK has been pushed and the formula builds successfully.

## Create the homebrew-tap repo and push

1. Go to https://github.com/new
2. Create a repository named **homebrew-tap**
   - Owner: raitama1122
   - Public
   - **Do not** add README, .gitignore, or license (the tap has content)

3. Push the tap:

```bash
cd /opt/homebrew/Library/Taps/raitama1122/homebrew-tap
git push -u origin main
```

If using SSH:
```bash
git remote set-url origin git@github.com:raitama1122/homebrew-tap.git
git push -u origin main
```

## Test

```bash
brew install raitama1122/tap/clok
clok setting tools
```

## Done!

Users can install with:
```bash
brew install raitama1122/tap/clok
```
