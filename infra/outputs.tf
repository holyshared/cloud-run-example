output "resource_records" {
  value = google_cloud_run_domain_mapping.default.status.*.resource_records
}