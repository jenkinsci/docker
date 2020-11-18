# Jenkins Docker Build Scripts
The `.ci` folder holds all the build script necessary to build, tag and publish Docker containers. 
These build scripts can also be used locally for testing.


# Usage
### `publish-images.sh`
This script allows the user to build Jenkins images for various operating systems, JVMs and JDKs.

#### User Inputs

- `-f|--file` - Sets the path of the Dockerfile to be built
- `-i|--image` - The name of the image (not including the tag)
- `-t|--tag` - The tag given to the image being built
- `-a|--build-args` - Any build arguments that you want to pass into Docker (Multiple build args are separated by a space)
- `-b|--build-opts` - Any build options that you want to pass into Docker (Multiple build args are separated by a space)
- `-c|--context` - The build context needed to pass to Docker
- `-n|--dry-run` - If set the script will build images but not publish them
- `-d|--debug` - If set it enables debug statements for more information
- `--force` - Will publish the images no matter what (Will ignore --dry-run if set)

#### Examples

```commandline
/.ci/publish-images.sh -f 8/debian/buster/hotspot/Dockerfile -i jenkins -t 2.263-jdk8-hotspot-debian-buster -a "JENKINS_VERSION=2.263 JENKINS_SHA=4cbae521ed6c1421b30ee2c490466d3f0b67d33525478d67f61f2100900b6a39" -b "--no-cache --pull" -c .
```

### `publish-tags.sh`
This script allows the user to tag a given image with additional tags. Multiple tags can be applied at once.

#### User Inputs

- `-i|--image` - The full name of the image to be tagged
- `-t|--tags` - The additional tags that will be applied to the image
- `-n|--dry-run` - If set the script will tag the image but not publish
- `-d|--debug` - If set it enables debug statements for more information
- `--force` - Will publish the the newly tagged images no matter what (Will ignore --dry-run if set)

#### Examples

```commandline
./.ci/publish-tags.sh -i jenkins:2.263-jdk8-hotspot-debian-buster -t "2.263-debian-buster 2.263-debian debian-buster debian latest"
```

```commandline
./.ci/publish-tags.sh -i jenkins:2.249.3-jdk11-hotspot-debian-buster -t "2.224.3-debian-buster 2.249.3-lts-jdk11 lts-debian-buster lts-debian lts"
```

### `publish-manifest.sh`
This script allows the user to build and publish manifest for multi-arch images.

#### User Inputs

- `-m|--manifest-name` - The full name of the manifest that will be built
- `-i|--image-name` - The full name of the image that needs to be pulled (The name should not include the arch)
- `-a|--archs` - The list of architectures the manifest will support (`amd64`, `arm64`, `ppc64le`, `s390x`)
- `-n|--dry-run` - If set the script will tag the image but not publish
- `-d|--debug` - If set it enables debug statements for more information

#### Examples

```commandline
./.ci/publish-manifests.sh -m jenkins:debian -i jenkins:debian -a "amd64 arm64 ppc64le s390x"
```

### `publish.sh`
This script acts as a wrapper for `publish-images.sh`, `publish-tags.sh` and `publish-manifests.sh`. Based on user input
you are able to build all the images, tags, or manifests for a given operating system. Additionally, you can narrow down
the objects you are building by passing in certain values for a given JVM, JDK and operating system.  


#### User Inputs

- `--publish` - The object you want to build and publish (`images`, `tags`, or `manifests`)
- `--os-name` - Name of the operating system you want to build for (You can but down `all` to process all the support operating systems)
- `--jdk` - Number of the JDK version you want to build for (You can but down `all` to process all supported JDK versions)
- `--jvm` - Name of the JVM you want to build for (`openj9`, `hotspot` or `all`)
- `--start-after` - The version of Jenkins you want to start building after (Optional parameter)
- `--debug` - If set it enables debug statements for more information
- `--force` - If set it will pass the `force` flag to the build scripts. This will force publish whatever you are trying to build
- `--dry-run` - If set the script will build the object(image, tag, or manifest) but not publish it

#### Examples

```commandline
./.ci/publish.sh --publish images --os-name debian --jdk all --jvm all --start-after 2.240
```

```commandline
./.ci/publish.sh --publish tags --os-name all --jdk 11 --jvm all
```

```commandline
./.ci/publish.sh --publish manifests --os-name alpine --jdk 8 --jvm hotpsot
```

```commandline
./.ci/publish.sh --publish images --os-name ubuntu --jdk all --jvm openj9 --start-after 2.240 --dry-run
```