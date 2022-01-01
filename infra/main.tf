terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.90.1"
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
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "domains.googleapis.com",
    "logging.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

resource "google_project_iam_member" "secretmanager_secret_accessor" {
  project  = module.project-factory.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.project-factory.project_number}@cloudbuild.gserviceaccount.com"
}

resource "google_cloud_run_service" "default" {
  name     = "cloudrun-srv"
  location = var.location
  project  = module.project-factory.project_id

  template {
    spec {
      containers {
        image = "gcr.io/clound-run-example-b1f8/cloud-run-example:latest"
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
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_domain_mapping" "default" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  name     = var.domain_name

  metadata {
    namespace = module.project-factory.project_id
  }

  spec {
    route_name = google_cloud_run_service.default.name
  }
}

resource "google_cloudbuild_trigger" "cloud_run_example_trigger" {
  name = "cloud-run-example"
  project = module.project-factory.project_id

  github {
    name  = "cloud-run-example"
    owner = "holyshared"

    push {
      branch       = "main"
      invert_regex = false
    }
  }

  substitutions = {
    _REGION=var.location
    _IMAGE_NAME=var.image_name
  }

  filename = "cloudbuild.yml"
}