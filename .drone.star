repo_short_name = "manifest-test"
architectures = [ "amd64", "arm64" ]
versions = [ "3.14", "3.15" ]

def main(ctx):
  builds = []
  depends_on = []

  for arch in architectures:
    for v in versions:
      builds.append(step(v, arch))
      depends_on.append("%s-%s-%s" % (repo_short_name, v, arch))

  # Temporary bodge for latest tag - should be for loop
  builds.append(publish("3.14", depends_on))
  builds.append(publish("3.15", depends_on, ["latest"]))
  return builds

def step(alpinever,arch):
  vertest = "grep -q '%s' /etc/alpine-release && " % alpinever if alpinever != "edge" else ""
  return {
    "kind": "pipeline",
    "name": "%s-%s-%s" % (repo_short_name, alpinever, arch),
    "platform": {
	"os": "linux",
	"arch": arch,
    },
    "steps": [
      {
        "name": "build",
        "image": "spritsail/docker-build",
        "pull": "always",
        "settings": {
          "build_args": [
            "ALPINE_TAG=%s" % alpinever,
          ],
          "repo": "%s-%s-%s" % (repo_short_name, alpinever, arch),
          "buildkit": False,
        },
      },
      {
        "name": "test",
        "image": "spritsail/docker-test",
        "pull": "always",
        "settings": {
          "run": vertest + "su-exec nobody apk --version",
          "repo": "%s-%s-%s" % (repo_short_name, alpinever, arch),
        },
      },
      {
        "name": "publish",
        "image": "spritsail/docker-publish",
        "pull": "always",
        "settings": {
	  "from": "%s-%s-%s" % (repo_short_name, alpinever, arch),
          "repo": "192.168.1.5:5000/%s-%s-%s" % (repo_short_name, alpinever, arch),
          "username": {"from_secret": "docker_username"},
          "password": {"from_secret": "docker_password"},
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ]
  }

def publish(alpinever,depends,tags=[]):
  return {
    "kind": "pipeline",
    "name": "%s-%s-publish" % (repo_short_name, alpinever, arch),
    "platform": {
	"os": "linux",
	"arch": arch,
    },
    "depends_on": depends,
    "steps": [
      {
        "name": "publish",
        "image": "spritsail/docker-multiarch-publish",
        "pull": "always",
        "settings": {
	  "from_repo": "192.168.1.5:5000/%s-%s" % (repo_short_name, alpinever),
	  "from_template": "192.168.1.5:5000/%s-%s-ARCH" % (repo_short_name, alpinever),
          "to_repo": "docker.io/adamant/multiarch",
          "to_username": {"from_secret": "docker_username"},
          "to_password": {"from_secret": "docker_password"},
          "tags": [alpinever] + tags,
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ]
  }
