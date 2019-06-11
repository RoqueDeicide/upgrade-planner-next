workflow "New workflow" {
  on = "push"
  resolves = ["Roang-zero1/factorio-mod-actions"]
}

action "Roang-zero1/factorio-mod-actions" {
  uses = "Roang-zero1/factorio-mod-actions/luacheck@master"
  env {
    LUACHECKRC_URL = "https://raw.githubusercontent.com/Nexela/Factorio-luacheckrc/0.17/.luacheckrc"
    }
}
