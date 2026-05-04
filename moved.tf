moved {
  from = oci_core_instance.mud_proxy[1]
  to   = oci_core_instance.mud_proxy["2"]
}

moved {
  from = oci_core_instance.mud_proxy[2]
  to   = oci_core_instance.mud_proxy["3"]
}

moved {
  from = oci_core_instance.mud_proxy[3]
  to   = oci_core_instance.mud_proxy["4"]
}

moved {
  from = oci_monitoring_alarm.cpu_high[1]
  to   = oci_monitoring_alarm.cpu_high["2"]
}

moved {
  from = oci_monitoring_alarm.cpu_high[2]
  to   = oci_monitoring_alarm.cpu_high["3"]
}

moved {
  from = oci_monitoring_alarm.cpu_high[3]
  to   = oci_monitoring_alarm.cpu_high["4"]
}

moved {
  from = oci_monitoring_alarm.instance_availability[1]
  to   = oci_monitoring_alarm.instance_availability["2"]
}

moved {
  from = oci_monitoring_alarm.instance_availability[2]
  to   = oci_monitoring_alarm.instance_availability["3"]
}

moved {
  from = oci_monitoring_alarm.instance_availability[3]
  to   = oci_monitoring_alarm.instance_availability["4"]
}
