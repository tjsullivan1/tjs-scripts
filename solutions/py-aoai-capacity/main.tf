data "external" "test" {
  program = ["python", "./main.py", "--model-name", "OpenAI.Standard.text-davinci-003"]
}

locals {
  capacity = data.external.test.result
}

output "test" {
  value = local.capacity
}

output "remaining_capacity" {
  value = local.capacity.remaining
}