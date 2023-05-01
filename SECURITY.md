# Security Policy

The Jenkins project takes security seriously.
We make every possible effort to ensure users can adequately secure their automation infrastructure.

## Docker Image Publication

When an image is published, the latest image and the latest available packages are used.

We rely on the base image provider for the security of the system libraries.

## Reporting Security Vulnerabilities

Before reporting a vulnerability, here are some instructions.

If the finding is coming from a Software Composition Analysis (SCA) scanner:
- The scan must have been done on the latest version of the image.
- The package should have a fixed version provided in the base image that is not yet included in our image.

If the finding is coming from a manual audit:
- Please follow the process about [Reporting Security Vulnerabilities](https://jenkins.io/security/reporting/).

We will reject reports coming from scanners without additional explanations.

## Vulnerability Management

Once the report is considered legitimate, a new image is published with the latest packages.
In the case the adjustment has to be done in the building process (e.g. in the Dockerfile), the correction will be prioritized and applied as soon as possible.

By default we do not plan to publish advisories for vulnerabilities at the Docker level. 
There may be exceptions.
