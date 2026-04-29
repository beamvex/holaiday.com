output "cloud_run_url" {
  value = google_cloud_run_v2_service.frontend.uri
}

output "artifact_registry_repository" {
  value = google_artifact_registry_repository.frontend.name
}

output "image_name" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.frontend.repository_id}/${var.service_name}"
}
