terraform {
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "3.90.1"
    }
  }
}

provider "google-beta" {
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

  default_service_account = "keep"
}

resource "google_project_iam_member" "secretmanager_secret_accessor" {
  project = module.project-factory.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.project-factory.project_number}@cloudbuild.gserviceaccount.com"
}

/**
 * Secret Manager
 */
resource "google_secret_manager_secret" "database_password" {
  project  = module.project-factory.project_id
  provider = google-beta

  secret_id = "database_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "database_password_version_data" {
  provider = google-beta

  secret      = google_secret_manager_secret.database_password.name
  secret_data = var.database_password
}

resource "google_secret_manager_secret_iam_member" "database_password_access" {
  project  = module.project-factory.project_id
  provider = google-beta

  secret_id  = google_secret_manager_secret.database_password.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${module.project-factory.project_number}-compute@developer.gserviceaccount.com"
  depends_on = [google_secret_manager_secret.database_password]
}



resource "google_cloud_run_service" "default" {
  name     = var.service_name
  location = var.location
  project  = module.project-factory.project_id

  provider = google-beta

  metadata {
    annotations = {
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  template {
    spec {
      containers {
        image = "asia.gcr.io/${module.project-factory.project_id}/cloud-run-example/${var.service_name}:latest"
        env {
          name  = "NODE_ENV"
          value = var.env
        }
        env {
          name = "DATABASE_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.database_password.secret_id
              key  = "latest"
            }
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      metadata.0.annotations,
    ]
  }

  depends_on = [
    google_secret_manager_secret_version.database_password_version_data
  ]
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
  provider = google-beta

  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_domain_mapping" "default" {
  provider = google-beta

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
  name    = "cloud-run-example"
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
    _REGION       = var.location
    _SERVICE_NAME = var.service_name
  }

  filename = "cloudbuild.yml"
}