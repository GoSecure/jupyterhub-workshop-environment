variable "workshop_name" {
  description = "What's the name of the workshop"
  type        = string
}

variable "workshop_domain" {
  description = "What will be this workshop's domain. Used for letsencrypt."
  type        = string
}

variable "workshop_contact" {
  description = "Workshop contact email. Used for letsencrypt."
  type        = string
}

variable "instance_region" {
  description = "DigitalOcean resource region"
  type        = string
  default     = "tor1"
}

variable "instance_size" {
  description = "DigitalOcean instance size"
  type        = string
  # You can find droplet sizes here: https://slugs.do-api.dev/
  default     = "s-1vcpu-2gb"
}

variable "tag_owner" {}
variable "tag_event" {}
variable "tag_purpose" {
  type = string
  default = "jupyterhub"
}
variable "do_token" {}

# JupyterHub
variable "jupyterhub_admin" {
  description = "This GitHub username will be admin of the JupyterHub server"
  type = string
}
variable "workshop_requirements_url" {
  description = "A URL to a Python requirements.txt file for dependencies to be installed on the system"
  type = string
}
variable "github_client_id" {}
variable "github_client_secret" {}

# Not managed by Terraform
data "digitalocean_project" "workshops" {
  name = "R&D Workshops"
}

# Tags
locals {
  tags = [
    var.workshop_name,
    var.tag_owner,
    var.tag_purpose,
    var.tag_event
  ]
}