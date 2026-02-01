variable "is_dr_active" {
  type = bool
}

variable "mongo_user" {
  type      = string
  sensitive = true
}

variable "mongo_password" {
  type      = string
  sensitive = true
}
