# ── ONS topic + email subscription ───────────────────────────────────────────
# Created only when alarm_email is set; alarms always exist and are visible in
# the OCI Monitoring console regardless.

resource "oci_ons_notification_topic" "alarms" {
  count          = var.alarm_email != "" ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = "tlbb-mud-proxy-alarms"
  description    = "Notification topic for mud-proxy monitoring alarms."
  freeform_tags  = local.common_tags
}

resource "oci_ons_subscription" "email" {
  count          = var.alarm_email != "" ? 1 : 0
  compartment_id = var.compartment_ocid
  endpoint       = var.alarm_email
  protocol       = "EMAIL"
  topic_id       = oci_ons_notification_topic.alarms[0].id
  freeform_tags  = local.common_tags
}

locals {
  alarm_destinations = var.alarm_email != "" ? [oci_ons_notification_topic.alarms[0].id] : []
}

# ── Monitoring alarms ─────────────────────────────────────────────────────────
# Both alarms target the compartment level, catching all mud-proxy instances.
# Destinations is empty when alarm_email is unset; OCI still shows the alarm
# state in the console.

resource "oci_monitoring_alarm" "cpu_high" {
  compartment_id        = var.compartment_ocid
  display_name          = "mud-proxy-cpu-high"
  is_enabled            = true
  metric_compartment_id = var.compartment_ocid
  namespace             = "oci_computeagent"
  query                 = "CpuUtilization[5m].mean() > ${var.alarm_cpu_threshold}"
  severity              = "WARNING"
  pending_duration      = "PT5M"
  destinations          = local.alarm_destinations
  message_format        = "ONS_OPTIMIZED"
  body                  = "CPU utilization has exceeded ${var.alarm_cpu_threshold}% on one or more mud-proxy instances for 5 minutes."
  freeform_tags         = local.common_tags
}

resource "oci_monitoring_alarm" "instance_availability" {
  compartment_id        = var.compartment_ocid
  display_name          = "mud-proxy-instance-availability"
  is_enabled            = true
  metric_compartment_id = var.compartment_ocid
  namespace             = "oci_computeagent"
  query                 = "CpuUtilization[5m].absent()"
  severity              = "CRITICAL"
  pending_duration      = "PT5M"
  destinations          = local.alarm_destinations
  message_format        = "ONS_OPTIMIZED"
  body                  = "A mud-proxy instance has stopped reporting metrics — it may be down or the compute agent may have stopped."
  freeform_tags         = local.common_tags
}

# ── VCN flow logs (optional) ──────────────────────────────────────────────────
# Disabled by default. When enabled, logs flow to a dedicated log group.
# OCI Always Free logging quota is 10 GB/month — keep retention short.

resource "oci_logging_log_group" "flow_logs" {
  count          = var.enable_flow_logs ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "mud-proxy-vcn-flow-logs"
  description    = "Log group for public subnet VCN flow logs."
  freeform_tags  = local.common_tags
}

resource "oci_logging_log" "subnet_flow" {
  count        = var.enable_flow_logs ? 1 : 0
  display_name = "public-subnet-flow-log"
  log_group_id = oci_logging_log_group.flow_logs[0].id
  log_type     = "SERVICE"
  is_enabled   = true

  configuration {
    source {
      category    = "all"
      resource    = oci_core_subnet.public.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.compartment_ocid
  }

  retention_duration = var.flow_logs_retention_days
  freeform_tags      = local.common_tags
}
