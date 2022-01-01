variable "location" {
  type    = string
  default = "asia-northeast1"
}

variable "org_id" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "env" {
  type = string
  default = "dev"
}

variable "image_name" {
  type = string
}
