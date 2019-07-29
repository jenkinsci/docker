CHANGELOG
=========

| See [GitHub releases](https://github.com/jenkinsci/docker/releases) |
| --- |

## Status

We are doing experimental changelogs for Jenkins master Docker packaging
([discussion in the developer list](https://groups.google.com/forum/#!topic/jenkinsci-dev/KvV_UjU02gE)). 
This release notes represent changes in in the packaging, but not in the bundled WAR files. 
Please refer to https://jenkins.io/changelog/ and https://jenkins.io/changelog-stable/ for WAR file changelogs.

## Version scheme

The repository follows the 3-digit scheme of [Jenkins LTS releases](https://jenkins.io/download/lts/).

## Mapping of Docker packaging to Jenkins releases

Both Weekly and LTS distributions follow the Continuous Delivery approach and pick up the most recent versions available by the time of the release Pipeline execution.
In this repository we follow the Jenkins LTS releases and release packaging changelogs for them.
There is no version mapping for Weekly releases, users should be using changelogs to track down the changes
(see also [Issue #865](https://github.com/jenkinsci/docker/issues/865)).

## Notable changes in Jenkins versions before 2.164.1

Below you can find incomplete list of changes in Docker packaging for Jenkins releases

### 2.99

*  `/bin/tini` has been relocated to `/sbin/tini`, location defined by alpine
