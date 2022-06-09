def main(ctx):
  return [
    step("3.14","arm64"),
    step("3.14","amd64"),
    step("3.15","arm64",["latest"]),
    step("3.15","amd64",["latest"]),
  ]

def step(alpinever,arch,tags=[]):
  vertest = "grep -q '%s' /etc/alpine-release && " % alpinever if alpinever != "edge" else ""
  return {
    "kind": "pipeline",
    "name": "build-%s-%s" % (alpinever, arch),
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
        },
      },
      {
        "name": "test",
        "image": "spritsail/docker-test",
        "pull": "always",
        "settings": {
          "run": vertest + "su-exec nobody apk --version",
        },
      },
      {
        "name": "publish",
        "image": "spritsail/docker-publish",
        "pull": "always",
        "settings": {
          "repo": "spritsail/manifest-test",
          "tags": [alpinever] + tags,
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

