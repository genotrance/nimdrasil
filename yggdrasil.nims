import os, strformat, strutils

let
  julia = findExe("julia")
  home = getEnv("HOME")
  juliadev = home / ".julia/dev"
  user = "genotrance"
  repo = "binaries"

if not fileExists(julia):
  echo "Could not find julia in path"
  quit()

if system.paramCount() < 5:
  echo "nim e yggdrasil path pkgname version1,version2"
  quit()

let
  yggd = system.paramStr(3)
  pkg = system.paramStr(4)
  vers = system.paramStr(5)
  dir = yggd / $pkg[0].toUpperAscii / pkg

if not system.dirExists(yggd):
  echo "Could not find " & yggd
  quit()

if not system.dirExists(dir):
  echo &"Could not find {dir}"
  quit()

for ver in vers.split(","):
  echo &"Building {pkg} v{ver}"

  withDir(dir):
    let
      build = "build_tarballs.jl"
    if not system.fileExists(build):
      echo &"Build file {dir}/{build} missing"
      quit()

    # Update version and tag
    var
      data = readFile(build)
      outdata = ""
      gitrepo = ""
      commit = ""
    for line in data.splitLines():
      if line.startsWith("version = v"):
        outdata &= &"version = v\"{ver}\"\n"
      elif line.contains("GitSource"):
        let
          spl = line.split("\"")
          (outp, err) = gorgeEx(&"git ls-remote {spl[1]}")
        gitrepo = spl[1]
        for line2 in outp.splitLines():
          if line2.contains("v" & ver):
            commit = line2.split('\t')[0]
        doAssert commit.len != 0, &"No matching commit found for v{ver}"
        outdata &= line & "\n"
      elif commit.len != 0:
        let
          spl = line.split("\"")
        outdata &= [spl[0], commit, spl[2]].join("\"") & "\n"
        commit = ""
      else:
        outdata &= line & "\n"
    writeFile(build, outdata)

    # Build artifacts
    rmDir("products")
    putEnv("BINARYBUILDER_AUTOMATIC_APPLE", "true")
    exec &"{julia} --color=yes {build} --deploy=\"fake/fake\""

    # Upload to bintray
    withDir("products"):
      let
        pkgpath = &"{user}/{repo}/{pkg}"
        verpath = &"{pkgpath}/v{ver}"

      var
        # Check if package exists
        (outp, err) = gorgeEx(&"jfrog bt ps {pkgpath}")

      # Create package
      if err != 0:
        exec &"jfrog bt pc --vcs-url {gitrepo} {pkgpath}"

      # Create version
      (outp, err) = gorgeEx(&"jfrog bt vs {verpath}")
      if err != 0:
        exec &"jfrog bt vc {verpath}"

      # Upload files
      exec &"jfrog bt u --publish \"*.gz\" {verpath} {pkg}-v{ver}/"

      # Upload toml files
      withDir(juliadev / &"{pkg}_jll"):
        let
          atoml = "Artifacts.toml"
          ptoml = "Project.toml"
          data = readFile(atoml)
        writeFile(atoml, data.replace(
          &"https://github.com/fake/fake/releases/download/{pkg}-v{ver}+0",
          &"https://bintray.com/{user}/{repo}/download_file?file_path={pkg}-v{ver}"
        ))

        exec &"jfrog bt u --publish \"*.toml\" {verpath} {pkg}-v{ver}/"