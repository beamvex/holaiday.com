provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  cloudbuild_sa = "${data.google_project.this.number}@cloudbuild.gserviceaccount.com"
  image_repo    = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.frontend.repository_id}"
  image_name    = "${local.image_repo}/${var.service_name}"
}

resource "google_project_service" "run" {
  project = var.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"
}

resource "google_artifact_registry_repository" "frontend" {
  location      = var.region
  repository_id = var.artifact_repo_id
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

resource "google_service_account" "cloudrun" {
  account_id   = "${var.service_name}-run"
  display_name = "${var.service_name} Cloud Run runtime"

  depends_on = [google_project_service.iam]
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${local.cloudbuild_sa}"

  depends_on = [google_project_service.run, google_project_service.cloudbuild]
}

resource "google_project_iam_member" "cloudbuild_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.cloudbuild_sa}"

  depends_on = [google_project_service.artifactregistry, google_project_service.cloudbuild]
}

resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  service_account_id = google_service_account.cloudrun.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloudbuild_sa}"

  depends_on = [google_project_service.iam, google_project_service.cloudbuild]
}

resource "google_cloud_run_v2_service" "frontend" {
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.cloudrun.email

    containers {
      image = "gcr.io/cloudrun/hello"

      ports {
        container_port = 80
      }
    }
  }

  depends_on = [google_project_service.run]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  name     = google_cloud_run_v2_service.frontend.name
  location = google_cloud_run_v2_service.frontend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloudbuild_trigger" "frontend" {
  name = "${var.service_name}-deploy"

  github {
    owner = var.github_owner
    name  = var.github_repo

    push {
      branch = var.github_branch_regex
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _REGION  = var.region
    _REPO    = google_artifact_registry_repository.frontend.repository_id
    _SERVICE = var.service_name
    _IMAGE   = local.image_name
  }

  depends_on = [
    google_project_service.cloudbuild,
    google_artifact_registry_repository.frontend,
    google_cloud_run_v2_service.frontend,
    google_project_iam_member.cloudbuild_run_admin,
    google_project_iam_member.cloudbuild_ar_writer,
    google_service_account_iam_member.cloudbuild_sa_user,
  ]
}
