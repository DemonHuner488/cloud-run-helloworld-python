cat > infra/main.tf <<'HCL'
terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.ar_repo
  format        = "DOCKER"
}

resource "google_service_account" "run_sa" {
  account_id   = "cr-webapp-sa"
  display_name = "Cloud Run runtime SA"
}

resource "google_artifact_registry_repository_iam_member" "run_sa_reader" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.run_sa.email}"
}

data "google_project" "proj" {
  project_id = var.project_id
}

locals {
  cloudbuild_sa = "${data.google_project.proj.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_custom_role" "custom_run_admin" {
  role_id     = "customRunAdmin"
  title       = "Custom Cloud Run Admin"
  description = "Custom role to manage Cloud Run services"
  permissions = var.custom_run_admin_permissions
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = google_project_iam_custom_role.custom_run_admin.name
  member  = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  service_account_id = google_service_account.run_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_compute_security_policy" "armor" {
  name = "webapp-armor"

  rule {
    priority = 1000
    action   = "deny(403)"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [var.blocked_ip_cidr]
      }
    }
    description = "Block test IP"
  }

  rule {
    priority = 2147483647
    action   = "allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    description = "Default allow"
  }
}
HCL

