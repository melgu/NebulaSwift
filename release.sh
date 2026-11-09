#!/bin/zsh
# Releases the macOS app: checks that it compiles for macOS and iOS, asks for the release notes in
# the editor, archives and zips the app, tags and pushes, creates the GitHub release, updates the
# Homebrew cask (creating it on the first release) and installs the app to /Applications.
#
# Usage: ./release.sh [--dry-run] [--prerelease] [--notes <file>]
#   --dry-run     Run the checks, builds, notes and archive, show what would be published and stop.
#                 Nothing is tagged, pushed, uploaded or installed.
#   --prerelease  Mark the GitHub release as a pre-release.
#   --notes       Open the editor with this file instead of the template.
#
# Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in a "Bump version to X" commit first, and run
# it on main with a clean working copy. It needs gh (logged in) and a clone of melgu/homebrew-tap
# at ../homebrew-tap (or NEBULA_TAP_DIR).

set -euo pipefail
setopt extendedglob

fail() {
	print -r -- "Error: $1" >&2
	exit 1
}

step() {
	print -r -- ""
	print -r -- "==> $1"
}

ask() {
	local answer
	read "answer?$1 [y/N] "
	[[ $answer == [yY]* ]]
}

usage="Usage: $0 [--dry-run] [--prerelease] [--notes <file>]"
dry_run=0
prerelease=0
notes_input=
while (( $# )); do
	case $1 in
		--dry-run) dry_run=1 ;;
		--prerelease) prerelease=1 ;;
		--notes)
			(( $# >= 2 )) || fail $usage
			notes_input=${2:A}
			[[ -f $notes_input ]] || fail "There is no notes file at $notes_input."
			shift
			;;
		*) fail $usage ;;
	esac
	shift
done

cd "${0:A:h}"
# Git over SSH fails instead of waiting for input that never comes
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15}

repo_url=https://github.com/melgu/NebulaSwift
tap=${NEBULA_TAP_DIR:-../homebrew-tap}
cask=$tap/Casks/nebulaswift.rb
tap_readme=$tap/README.md
tap_row='| [NebulaSwift](https://github.com/melgu/NebulaSwift) | `brew install --cask melgu/tap/nebulaswift` | Nebula client for macOS |'

# MARK: Checks

step "Checking the setup"
for tool in gh xcodebuild brew trash; do
	command -v $tool >/dev/null || fail "$tool is missing."
done
gh auth status >/dev/null 2>&1 || fail "Log in with gh auth login first."
[[ -d $tap/Casks ]] || fail "No tap at $tap. Clone melgu/homebrew-tap there or set NEBULA_TAP_DIR."

# A dry run is mostly made before committing, so these only warn there
problems=()
[[ $(git branch --show-current) == main ]] || problems+="Releases are made from main."
[[ -z $(git status --porcelain) ]] || problems+="Commit or stash the changes first."
git fetch -q origin
git merge-base --is-ancestor origin/main HEAD || problems+="main is behind origin/main. Pull first."
[[ $(git -C "$tap" branch --show-current) == main && -z $(git -C "$tap" status --porcelain) ]] || problems+="The tap at $tap has to be on main and clean."
if (( ${#problems} )); then
	if (( dry_run )); then
		for problem in $problems; do
			print -r -- "Warning: $problem"
		done
	else
		fail "${(F)problems}"
	fi
fi

settings=$(xcodebuild -project NebulaSwift.xcodeproj -scheme NebulaSwift -configuration Release -destination 'generic/platform=macOS' -showBuildSettings 2>/dev/null)
setting() {
	local -a matches=(${(M)${(f)settings}:#[[:space:]]#$1 = *})
	print -r -- "${${matches[1]:-}#*= }"
}
version=$(setting MARKETING_VERSION)
build=$(setting CURRENT_PROJECT_VERSION)
min_os=$(setting MACOSX_DEPLOYMENT_TARGET)
[[ -n $version && -n $build && -n $min_os ]] || fail "Couldn't read the version, build and deployment target from the project."
tag=$version-$build
min_os_parts=("${(@s:.:)min_os}")
# Homebrew names macOS versions in depends_on
case ${min_os_parts[1]} in
	14) macos_name=sonoma ;;
	15) macos_name=sequoia ;;
	26) macos_name=tahoe ;;
	*) fail "Add the Homebrew name of macOS $min_os to release.sh." ;;
esac
print -r -- "NebulaSwift $version ($build), tag $tag, macOS $min_os or later"

! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || fail "Tag $tag exists already. Bump the version first."
remote_tag=$(git ls-remote --tags origin "refs/tags/$tag") || fail "Couldn't check the tags on GitHub."
[[ -z $remote_tag ]] || fail "Tag $tag exists on GitHub already."
if [[ -f $cask ]]; then
	cask_version=$(sed -nE 's/^  version "(.*)"$/\1/p' "$cask")
	last_build=${cask_version##*-}
	(( build > last_build )) || fail "Build $build isn't newer than the cask's build $last_build. Bump the version first."
fi

work=${TMPDIR:-/tmp}
work=${work%/}/NebulaSwift-release-$tag
mkdir -p "$work"

# MARK: Compiling

step "Checking that it compiles"
for platform in macOS 'iOS Simulator'; do
	print -r -- "Building for $platform…"
	log=$work/build-${platform// /-}.log
	if ! xcodebuild -project NebulaSwift.xcodeproj -scheme NebulaSwift -configuration Debug -destination "generic/platform=$platform" build >|$log 2>&1; then
		grep -m 20 'error:' $log || true
		fail "The build for $platform failed. Log: $log"
	fi
done

# MARK: Release notes

step "Release notes"
notes=$work/notes.md
if [[ -n $notes_input ]]; then
	cp "$notes_input" "$notes"
elif [[ -f $notes ]]; then
	print -r -- "Continuing with the notes from the last run."
else
	last_tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
	commits=$(git log --format='- %s' ${last_tag:+$last_tag..}HEAD)
	cat >|$notes <<-EOF
	#

	New
	-

	Improvements
	-

	Fixes
	-

	<!--
	Release notes for NebulaSwift $version ($build), in Markdown. The first line is the title, the
	rest the text. Delete the sections you don't need. This comment is left out.

	Commits since ${last_tag:-the first one}:
	$commits
	-->
	EOF
fi

editor=${VISUAL:-${EDITOR:-}}
edit_notes() {
	if [[ -n $editor ]]; then
		${=editor} "$notes"
	else
		print -r -- "Quit TextEdit when you're done."
		open -W -t "$notes"
	fi
}

# Sets title and body from the notes file, or explains what's wrong and returns 1
parse_notes() {
	local content=$(perl -0pe 's/<!--.*?-->\n?//gs' "$notes")
	local -a lines=("${(@f)content}")
	local i=1
	while (( i <= ${#lines} )) && [[ -z ${lines[i]//[[:space:]]/} ]]; do
		(( i += 1 ))
	done
	local title_line=${lines[i]:-}
	title=${${title_line#\#}##[[:space:]]#}
	title=${title%%[[:space:]]#}
	if [[ $title_line != '# '* || -z $title ]]; then
		print -r -- "The first line has to be the title, like: # Picture in Picture on the Mac"
		return 1
	fi
	body=${(F)lines[i+1,-1]}
	body=${body##[[:space:]]#}
	body=${body%%[[:space:]]#}
	if [[ -z $body ]]; then
		print -r -- "The text below the title is empty."
		return 1
	fi
	if [[ -n ${(M)${(f)body}:#[[:space:]]#[-*][[:space:]]#} ]]; then
		print -r -- "There are empty list items. Fill them in or delete them."
		return 1
	fi
}

while true; do
	edit_notes
	parse_notes && break
	ask "Edit the notes again?" || fail "Stopped. The notes are kept in $notes for the next run."
done

release_body=$work/release-body.md
print -r -- "# $title"$'\n\n'"$body" >|$release_body

# MARK: Archive

step "Archiving"
if (( dry_run )); then
	archive=$work/NebulaSwift.xcarchive
	[[ -e $archive ]] && trash "$archive"
else
	archive=~/Library/Developer/Xcode/Archives/$(date +%F)/"NebulaSwift $tag.xcarchive"
	[[ ! -e $archive ]] || fail "There is an archive at $archive already."
fi
log=$work/archive.log
if ! xcodebuild -project NebulaSwift.xcodeproj -scheme NebulaSwift -configuration Release -destination 'generic/platform=macOS' -allowProvisioningUpdates -archivePath "$archive" archive >|$log 2>&1; then
	grep -m 20 'error:' $log || true
	if grep -q errSecInternalComponent $log; then
		print -r -- "Signing needs the login keychain. Unlock it with: security unlock-keychain ~/Library/Keychains/login.keychain-db"
	fi
	fail "Archiving failed. Log: $log"
fi
app=$archive/Products/Applications/NebulaSwift.app
[[ $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist") == $version ]] || fail "The archived app has the wrong version."
[[ $(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist") == $build ]] || fail "The archived app has the wrong build."
codesign --verify --deep --strict "$app" || fail "The archived app's signature isn't valid."

zip=$work/NebulaSwift.zip
[[ -e $zip ]] && trash "$zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
sha=$(shasum -a 256 "$zip" | cut -d ' ' -f 1)
print -r -- "Archive: $archive"

# MARK: Summary

step "Release $tag"
print -r -- "GitHub release: $version ($build)$( (( prerelease )) && print -n ', pre-release')"
print -r -- "Zip SHA-256:    $sha"
print -r -- "Minimum macOS:  $min_os ($macos_name)"
print -r -- ""
print -r -- "--- GitHub release notes ---"
cat "$release_body"

if (( dry_run )); then
	step "Dry run: stopping before publishing"
	print -r -- "A real run would now:"
	print -r -- "- tag HEAD as $tag and push main and the tag"
	print -r -- "- create the GitHub release $tag with the zip"
	if [[ -f $cask ]]; then
		print -r -- "- set the cask to $tag with SHA-256 $sha and macOS $macos_name, commit and push the tap"
	else
		print -r -- "- create the cask for $tag with SHA-256 $sha, add it to the tap's README, commit and push the tap"
	fi
	print -r -- "- install the app to /Applications"
	print -r -- ""
	print -r -- "Everything is in $work"
	exit 0
fi

ask "Publish $tag?" || fail "Stopped before publishing. The notes are kept in $notes for the next run."

# MARK: Publishing

step "Tagging $tag"
git tag -a "$tag" -m ""
git push -q origin main "refs/tags/$tag"

step "Creating the GitHub release"
release_flags=()
(( prerelease )) && release_flags+=--prerelease
gh release create "$tag" "$zip" --title "$version ($build)" --notes-file "$release_body" --verify-tag $release_flags
mkdir -p "$work/check"
gh release download "$tag" -p NebulaSwift.zip -D "$work/check" --clobber
[[ $(shasum -a 256 "$work/check/NebulaSwift.zip" | cut -d ' ' -f 1) == $sha ]] || fail "The zip on GitHub doesn't match the built one."

step "Updating the Homebrew cask"
git -C "$tap" pull -q --ff-only
if [[ -f $cask ]]; then
	tap_message="nebulaswift $tag"
	sed -i '' -E "s/^  version \".*\"$/  version \"$tag\"/; s/^  sha256 \".*\"$/  sha256 \"$sha\"/; s/^  depends_on macos: :.*$/  depends_on macos: :$macos_name/" "$cask"
else
	tap_message="nebulaswift $tag (new cask)"
	cat >|$cask <<-EOF
	cask "nebulaswift" do
	  version "$tag"
	  sha256 "$sha"

	  url "https://github.com/melgu/NebulaSwift/releases/download/#{version}/NebulaSwift.zip"
	  name "NebulaSwift"
	  desc "Unofficial client for the Nebula streaming service"
	  homepage "https://github.com/melgu/NebulaSwift"

	  depends_on macos: :$macos_name

	  app "NebulaSwift.app"

	  # The app isn't notarized, so Gatekeeper would refuse to open it
	  postflight_steps do
	    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/NebulaSwift.app"]
	  end

	  zap trash: [
	    "~/Library/Application Scripts/de.melgu.NebulaSwift",
	    "~/Library/Containers/de.melgu.NebulaSwift",
	  ]
	end
	EOF
fi
grep -qx "  version \"$tag\"" "$cask" && grep -qx "  sha256 \"$sha\"" "$cask" && grep -qx "  depends_on macos: :$macos_name" "$cask" || fail "Couldn't set the version, SHA-256 and minimum macOS in $cask."
if ! grep -qF -- "$tap_row" "$tap_readme"; then
	# Below the table's header, as NebulaSwift comes first alphabetically
	TAP_ROW=$tap_row perl -pi -e '$_ .= "$ENV{TAP_ROW}\n" if /^\|---/ && !$done++' "$tap_readme"
	grep -qF -- "$tap_row" "$tap_readme" || fail "Couldn't add NebulaSwift to $tap_readme."
fi
brew style melgu/tap
git -C "$tap" add Casks/nebulaswift.rb README.md
git -C "$tap" commit -qm "$tap_message"
git -C "$tap" push -q

step "Installing to /Applications"
install=1
if pgrep -xq NebulaSwift; then
	if ask "NebulaSwift is running. Quit it to install $tag?"; then
		osascript -e 'quit app "NebulaSwift"'
		for _ in {1..20}; do
			pgrep -xq NebulaSwift || break
			sleep 1
		done
		! pgrep -xq NebulaSwift || fail "NebulaSwift didn't quit. Install it from $app by hand."
	else
		install=0
		print -r -- "Skipped. The app is in $app."
	fi
fi
if (( install )); then
	[[ -e /Applications/NebulaSwift.app ]] && trash /Applications/NebulaSwift.app
	ditto "$app" /Applications/NebulaSwift.app
	[[ $(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' /Applications/NebulaSwift.app/Contents/Info.plist) == $build ]] || fail "The installed app has the wrong build."
	codesign --verify --deep --strict /Applications/NebulaSwift.app || fail "The installed app's signature isn't valid."
fi

trash "$work"
step "Released $tag: $repo_url/releases/tag/$tag"
