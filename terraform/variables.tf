variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west2"
}

variable "service_name" {
  type    = string
  default = "holaiday-com"
}

variable "artifact_repo_id" {
  type    = string
  default = "frontend"
}

variable "github_owner" {
  type    = string
  default = "beamvex"
}

variable "github_repo" {
  type    = string
  default = "holaiday.com"
}

variable "github_branch_regex" {
  type    = string
  default = "^main$"
}
