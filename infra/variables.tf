cat > infra/variables.tf <<'HCL'
variable "project_id" { type = string }
variable "region"     { type = string  default = "us-central1" }

variable "ar_repo" {
  type    = string
  default = "webapp"
}

variable "cloud_run_service_name" {
  type    = string
  default = "webapp"
}

variable "blocked_ip_cidr" {
  type    = string
  default = "1.2.3.4/32"
}

variable "custom_run_admin_permissions" {
  type = list(string)
}
HCL

