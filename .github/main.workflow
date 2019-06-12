workflow "New workflow" {
  on       = "push"

  resolves = [
    "package"
  ]
}

action "luacheck" {
  uses = "Roang-zero1/factorio-mod-actions/luacheck@master"

  env  = {
    LUACHECKRC_URL = "https://raw.githubusercontent.com/Nexela/Factorio-luacheckrc/0.17/.luacheckrc"
  }
}

action "package" {
  uses  = "Roang-zero1/factorio-mod-actions/package@master"

  needs = [
    "luacheck"
  ]
}
