variable "aws_region" {
  default = "us-east-1"
}
variable "availabilityZone" {
  default = "us-east-1a"
}
# variable "instanceTenancy" {
#     default = "default"
# }
# variable "dnsSupport" {
#     default = true
# }
# variable "dnsHostNames" {
#     default = true
# }
# variable "cidr_block" {
#     default = "10.0.0.0/16"
# }
# variable "subnet_cidr_block"
#     default = "10.0.1.0/24"
# }
# variable "builder_cidr_block" {
#     default = "10.0.3.0/24"
# }
# variable "destinationCIDRblock" {
#     default = "0.0.0.0/0"
# }
# variable "ingressCIDRblock" {
#     type = list
#     default = [ "0.0.0.0/0" ]
# }
# variable "egressCIDRblock" {
#     type = list
#     default = [ "0.0.0.0/0" ]
# }
variable "mapPublicIP" {
  default = true
}
variable "wsAssetsSubDomainName" {
  default = "assets"
}
variable "baseDomainName" {
  default = "kinetic.sandbox.openstax.org"
}
variable "subDomainName" {
  default = "workspaces"
}

variable "sso_cookie_name" {
  description = "The name of the OpenStax session cookie"
  sensitive   = true
}

variable "sso_cookie_private_key" {
  description = "Private key used to decode OpenStax session cookie"
  sensitive   = true
}

variable "sso_cookie_public_key" {
  description = "Public key used to decode OpenStax session cookie"
  sensitive   = true
}

variable "environment_name" {
  description = "Name of environment"
  default     = "staging"
}

variable "editor_login" {
  default     = "kinetic"
  description = "Username of user on editor instances"
}

variable "kinetic_url" {
  description = "URL to the main kinetic app"
}
variable "email_address_notification" {
  default = "nathan.stitt@rice.edu"
}

