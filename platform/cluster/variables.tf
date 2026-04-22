variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "sim-apne2-cluster"
}

variable "cluster_version" {
  description = "EKS 버전"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-0e1b8458f46f9f81d"
}

variable "private_subnet_ids" {
  description = "Private 서브넷 (노드 + 컨트롤플레인 ENI)"
  type        = list(string)
  default = [
    "subnet-038d2a0c3356f1fb9", # production-private-ap-northeast-2a
    "subnet-0dbe1ba15318053d7", # production-private-ap-northeast-2c
  ]
}

variable "public_subnet_ids" {
  description = "Public 서브넷 (ALB용)"
  type        = list(string)
  default = [
    "subnet-053d1ebe1e70a4ead", # production-public-ap-northeast-2a
    "subnet-0e6a6bcf943572f7b", # production-public-ap-northeast-2c
  ]
}

variable "node_instance_types" {
  description = "노드 그룹 인스턴스 타입"
  type        = list(string)
  default     = ["m5.xlarge"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 10
}
