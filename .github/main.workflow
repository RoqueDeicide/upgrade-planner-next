workflow "New workflow" {
  on = "push"
  resolves = ["Roang-zero1/factorio-mod-actions"]
}

action "Filters for GitHub Actions" {
  uses = "actions/bin/filter@3c0b4f0e63ea54ea5df2914b4fabf383368cd0da"
  args = "tag"
}

action "Roang-zero1/factorio-mod-actions" {
  uses = "Roang-zero1/factorio-mod-actions/luacheck@master"
  needs = ["Filters for GitHub Actions"]
  args = "Test"
}
