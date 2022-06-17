repo_short_name = "manifest-test"
architectures = ["amd64", "arm64"]
versions = [ "3.16"]

def main(ctx):
  builds = []
  depends_on = []

  for arch in architectures:
    for v in versions:
      builds.append(step(v, arch))
      depends_on.append("%s-%s-%s" % (repo_short_name, v, arch))
    
  for v in versions:
    latest = []
    if v == versions[-1]:
      latest = [ "latest", "butts", "athirdtag" ]
    builds.append(publish(v, depends_on, latest))

  return builds

def step(alpinever,arch):
  vertest = "grep -q '%s' /etc/alpine-release && " % alpinever if alpinever != "edge" else ""
  stepimage = "%s-%s-%s" % (repo_short_name, alpinever, arch)
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
          "repo": stepimage,
          "buildkit": False,
        },
      },
      {
        "name": "test",
        "image": "spritsail/docker-test",
        "pull": "always",
        "settings": {
          "run": vertest + "su-exec nobody apk --version",
          "repo": stepimage,
        },
      },
      {
        "name": "publish",
        "image": "spritsail/docker-publish",
        "pull": "always",
        "settings": {
          "from": stepimage,
          "repo": stepimage,
          "registry": {"from_secret": "registry_url"},
          "username": {"from_secret": "registry_username"},
          "password": {"from_secret": "registry_password"},
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
    "name": "%s-%s-publish" % (repo_short_name, alpinever),
    "depends_on": depends,
    "steps": [
      {
        "name": "publish",
        "image": "spritsail/docker-multiarch-publish",
        "pull": "always",
        "settings": {
          "src_template": "%s-%s-ARCH:latest" % (repo_short_name, alpinever),
	  "src_username": {"from_secret": "registry_username"},
	  "src_password": {"from_secret": "registry_password"},
          "src_registry": {"from_secret": "registry_url"},
          "dest_repo": "docker.io/adamant/multiarch",
          "dest_username": {"from_secret": "docker_username"},
          "dest_password": {"from_secret": "docker_password"},
          "tags": [alpinever] + tags,
 	  "debug": "true",
        },
        "when": {
          "branch": ["master"],
          "event": ["push"],
        },
      },
    ]
  }
