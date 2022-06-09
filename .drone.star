repo_short_name = "manifest-test"
architectures = [ "amd64", "arm64" ]

def main(ctx):
  builds = []
  for arch in architectures:
    builds += step("3.14", arch)
    builds += step("3.15", arch, ["latest"])
  return builds

def step(alpinever,arch,tags=[]):
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

