terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.79.0"
    }
  }
}

provider "google" {
  region = var.location
}

module "project-factory" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 10.1"

  name              = "clound-run-example"
  random_project_id = true
  org_id            = var.org_id
  billing_account   = var.billing_account
  folder_id         = var.folder_id

  activate_apis = [
    "run.googleapis.com"
  ]
}

resource "google_cloud_run_service" "default" {
  name     = "cloudrun-srv"
  location = var.location
  project  = module.project-factory.project_id

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.default.location
  project     = google_cloud_run_service.default.project
  service     = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
