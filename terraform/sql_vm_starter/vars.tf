variable "subscription_id" {
  description = "The Azure subscription ID"

}

variable "data_disk_iops" {
  description = "The number of IOPS for the data disks"
  default     = 3000

}

variable "log_disk_iops" {
  description = "The number of IOPS for the log disks"
  default     = 3000
}

variable "data_disk_throughput" {
  description = "The throughput for the data disks"
  default     = 125

}

variable "log_disk_throughput" {
  description = "The throughput for the log disks"
  default     = 125

}

variable "offset" {
  description = "The offset for the data disks"

}