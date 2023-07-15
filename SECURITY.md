# Security Policy

The Jenkins project takes security seriously.
We make every possible effort to ensure users can adequately secure their automation infrastructure.

You can find more information in the [general Security Policy](https://github.com/jenkinsci/.github/blob/master/SECURITY.md), this policy is specific to our Docker images.

## Docker Image Publication

When an image is published, the latest image and the latest available packages are used.

We rely on the base image provider for the security of the system libraries.
The default base image is Debian but multiple other variants are proposed, that could potentially better fit your needs.

## Reporting Security Vulnerabilities

If you have identified a security vulnerability and would like to report it, please be aware of those requirements.

For findings from a **Software Composition Analysis (SCA) scanner report**, all of the following points must be satisfied:
- If the finding is coming from the system (Docker layer):
  - The scan must have been done on the latest version of the image.
Vulnerabilities are discovered in a continuous way, so it is expected that past releases could contain some.
  - The package should have a fixed version provided in the base image that is not yet included in our image.
We rely on the base image provider to propose the corrections.
  - The correction should have existed at the time the image was created.
Normally our update workflow ensures that the latest available versions are used.
- If the finding is coming from the application dependencies:
  - Proof of exploitation or sufficiently good explanation about why you think it's impacting the application.

For all "valid" findings from SCA, your report must contain:
- The path to the library (there are ~2000 components in the ecosystem, we don't want to have to guess)
- The version and variant of the Docker image you scanned.
- The scanner name and version as well.
- The publicly accessible information about the vulnerability (ideally CVE). For private vulnerability database, please provide all the information at your disposal.

The objective is to reduce the number of reports we receive that are not relevant to the security of the project.

For findings from a **manual audit**, the report must contain either reproduction steps or a sufficiently well described proof to demonstrate the impact.

Once the report is ready, please follow the process about [Reporting Security Vulnerabilities](https://jenkins.io/security/reporting/).

We will reject reports that are not satisfying those requirements.

## Vulnerability Management

Once the report is considered legitimate, a new image is published with the latest packages.
In the case the adjustment has to be done in the building process (e.g. in the Dockerfile), the correction will be prioritized and applied as soon as possible.

By default we do not plan to publish advisories for vulnerabilities at the Docker level. 
There may be exceptions.
