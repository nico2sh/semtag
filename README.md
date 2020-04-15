# Semtag
Semantic Tagging Script for Git

[Version: v0.1.0]

Notes: *This script is inspired by the [Nebula Release Plugin](https://github.com/nebula-plugins/nebula-release-plugin), and borrows a couple of lines from [Semver Bash Tool](https://github.com/fsaintjacques/semver-tool) (mostly the version comparison and the semantic version regex).*

[A quick history of this script](https://medium.com/@dr_notsokind/semantic-tagging-with-git-1254dbded22)

This is a script to help out version bumping on a project following the [Semantic Versioning](http://semver.org/) specification. It uses Git Tags to keep track the versions and the commit log between them, so no extra files are needed. It can be combined with release scripts, git hooks, etc, to have a consistent versioning.

### Why Bash? (and requirements)

Portability, mostly. You can use the script in any project that uses Git as a version control system. The only requirement is Git.

### Why not use the Nebula-release plugin?

Nebula Release is for releasing and publishing components and tries to automate the whole process from tagging to publishing. Th goal of the `semtag` script is to only tag release versions, leaving the release process up to the developer.

Plus, the `semtag` sctipt doesn't depend on the build system (so no need to use Gradle), so it can be used in any project.

## Usage

Copy the `semtag` script in your project's directory.

Semtag distinguishes between final versions and non-final versions. Possible non-final versions are `alpha`, `beta` and `rc` (release candidate).

Starts from version `0.0.0`, so the first time you initialize a version, it will tag it with the following bumped one (`1.0.0` if major, `0.1.0` if minor, `0.0.1` if patch)

Use the script as follows:

```
$ semtag <commdand> <options>
```

Info commands:

* `getfinal` Returns the current final version.
* `getlast` Returns the last tagged version, it can be the final version or a non-final version.
* `getcurrent` Returns the current version, it can be the tagged final version or a tagged non-final version. If there are unstaged or uncommitted changes, they will be included in the version, following this format: `<major>.<minor>.<patch>-dev.#+<branch>.<hash>`. Where `#` is the number of commits since the last final release, `branch` will be the current branch if we are not in `master` and `hash` is the git hash of the current commit.
* `get` Returns both last tagged version and current final version.

Versioning commands:

* `final` Bumps the version top a final version
* `alpha` Bumps the version top an alpha version (appending `-alpha.#` to the version.
* `beta` Bumps the version top a beta version (appending `-beta.#` to the version.
* `candidate` Bumps the version top an release candidate version (appending `-rc.#` to the version.

Note: If there are no commits since the last final version, the version is not bumped.

All versioning commands tags the project with the new version using annotated tags (the tag message contains the list of commits included in the tag), and pushes the tag to the origin remote.

If you don't want to tag, but just display which would be the next bumped version, use the flag `-o` for showing the output only.

For specifying the scope you want to bump the version, use the `-s <scope>` option. Possible scopes are `major`, `minor` and `patch`. There is also `auto` which will choose between `minor` and `patch` depending on the percentage of lines changed. Usually it should be the developers decisions which scope to use, since the percentage of lines is not a great criteria, but this option is to help giving a more meaningful versioning when using in automatic scripts.

If you want to manually set a version, use the `-v <version>` option. Version must comply the semantic versioning specification (`v<major>.<minor>.<patch>`), and must be higher than the latest version. Works with any versioning command.

### Usage Examples

See the `release` script as an example. The script gets the next version to tag, uses that version to update the `README.md` file (this one!), and the script's. Then commits the changes, and finally tags the project with this latest version.

#### Gradle example

For setting up your project's version, in your `build.gradle` file, add the following:

```
version=getVersionTag()

def getVersionTag() {
  def hashStdOut = new ByteArrayOutputStream()
  exec {
    commandLine "$rootProject.projectDir/semtag", "getcurrent"
    standardOutput = hashStdOut
  }

  return hashStdOut.toString().trim()
}
```

This way, the project's version every time you make a build, will be aligned with the tagged version. On your CI script, you can tag the release version before deploying, or alternatively, before publishing to a central repository (such as Artifactory), you can create a Gradle task tagging the release version:

```
def tagFinalVersion() {
  exec {
    commandLine "$rootProject.projectDir/semtag", "final", "-s minor"
    standardOutput = hashStdOut
  }
  
  doLast {
    project.version=getVersionTag()
  }
}

artifactoryPublish.dependsOn tagFinalVersion
```

Or create your own task for tagging and releasing. The goal of this script is to provide flexibility on how to manage and deal with the releases and deploys.

## How does it bump

Semtag tries to guess which is the following version by using the current final version as a reference for bumping. For example:

```
$ semtag get
Current final version: v1.0.0
Last tagged version:   v1.0.0
$ semtag candidate -s minor
$ semtag get
Current final version: v1.0.0
Last tagged version:   v1.1.0-rc.1
```

Above it used the `v1.0.0` version for bumping a minor release candidate. If we try to increase a patch:

```
$ semtag candidate -s patch
$ semtag get
Current final version: v1.0.0
Last tagged version:   v1.1.0-rc.2
```

Again, it used the `v1.0.0` version as a reference to increase the patch version (so it should be bumped to `v1.0.1-rc.1`), but since the last tagged version is higher, it bumped the release candidate number instead. If we release a beta version:

```
$ semtag beta -s patch
$ semtag get
Current final version: v1.0.0
Last tagged version:   v1.1.1-beta.1
```

Now the patch has been bumped, since a beta version is considered to be lower than a release candidate, so is the verison number that bumps up, using the provided scope (`patch` in this case).

### Forcing a tag

Semtag doesn't tag if there are no new commits since the last version, or if there are unstaged changes. To force to tag, use the `-f` flag, then it will bump no matter if there are unstaged changes or no new commits.

### Version prefix

By default, semtag prefixes new versions with `v`. Use the `-p` (plain) flag which to create new versions with no `v` prefix.
