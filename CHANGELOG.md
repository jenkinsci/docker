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

The repository follows the [Semantic Versioning 2.0.0](https://semver.org/) specification.

## Mapping of Docker packaging to Jenkins releases

Currently there is no direct mapping of Docker packaging versions to Docker packages used in the official [jenkins/jenkins](https://hub.docker.com/r/jenkins/jenkins) image.
Both Weekly and LTS distributions follow the Continuous Delivery approach and pick up the most recent versions available by the time of the release Pipeline execution.
It is subject to change in the future.

## Notable changes in Jenkins versions

Below you can find incomplete list of changes in Docker packaging for Jenkins releases

2.99
-----
*  `/bin/tini` has been relocated to `/sbin/tini`, location defined by alpine
