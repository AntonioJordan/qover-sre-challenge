variable "is_dr_active" {
  type    = bool
  default = false
}

variable "mongo_user" {
  type    = string
  default = "appuser"
}

variable "mongo_password" {
  type    = string
  default = "123"
}
